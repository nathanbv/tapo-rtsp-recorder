#!/bin/bash
# set -x # Uncomment for debugging

ffmpeg_script_pid=0
readonly FFMPEG_SCRIPT="ffmpeg_rtsp_recorder.sh" # Path to the script using ffmpeg

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(realpath "$(dirname "$0")")"
readonly SCRIPT_PID="$$"
readonly LOG_HEADER="$(printf "%-24s - %-9d" ${SCRIPT_NAME} ${SCRIPT_PID})"

_log() {
    echo "$(date +'%Y-%m-%d_%H-%M-%S') [${LOG_HEADER}] $*"
}

log-debug() {
    # Disable debug logs for now
    # _log "DEBUG: $*"
}

log-info() {
    _log "INFO:  $*"
}

log-error() {
    _log "ERROR: $*"
}

kill-ffmpeg() {
    local SIGTERM="-15"
    # Forcefully terminate ffmpeg process and the script that launched it
    ffmpeg_pid=$(pgrep --parent ${ffmpeg_script_pid})
    if [ $? -eq 0 ]; then
        log-debug "Killing (${SIGTERM}) ffmpeg process with PID ${ffmpeg_pid}"
        kill "${SIGTERM}" "${ffmpeg_pid}" &> log-debug
    else
        log-debug "No running ffmpeg process found to kill"
    fi
    log-debug  "Killing (${SIGTERM}) ${FFMPEG_SCRIPT} with PID ${ffmpeg_script_pid}"
    kill "${SIGTERM}" "${ffmpeg_script_pid}" &> log-debug
}

launch-ffmpeg() {
    # Start the ffmpeg recording script in the background
    bash "${SCRIPT_PATH}/${FFMPEG_SCRIPT}" &

    # Get the PID of the most recently started ffmpeg process
    ffmpeg_script_pid=$!
    log-debug "Started ${FFMPEG_SCRIPT} with PID ${ffmpeg_script_pid}"
}

# Function to handle signals
function graceful_exit {
    log-error "Exiting ${SCRIPT_NAME}..."
    kill-ffmpeg
    exit 0
}

# Set up signal handler for SIGINT (Ctrl+c) and SIGTERM (used by systemd)
trap graceful_exit SIGINT SIGTERM

readonly CPU_THRESHOLD_PERCENT=2
readonly MONITOR_PERIOD_SEC=300 # Period at which the ffmpeg script will be monitored
readonly DEBOUNCE_COUNT=10
readonly DEBOUNCE_PERIOD_SEC=3

log-error "Script ${SCRIPT_NAME} started (from ${SCRIPT_PATH}/)"

# Initially start ffmpeg
launch-ffmpeg

# Count the number of times no ffmpeg process was found
ffmpeg_not_running_count=0
while true; do
    # Wait for a while before checking CPU utilization
    log-debug "Next monitoring polling in ${MONITOR_PERIOD_SEC}s"
    sleep ${MONITOR_PERIOD_SEC}

    log-debug "Start monitoring ffmpeg"
    below_threshold_count=0
    for ((it=1; it<=DEBOUNCE_COUNT; it++)); do
        # Try to find the ffmpeg process spawned by the script
        ffmpeg_pid=$(pgrep --parent ${ffmpeg_script_pid})
        if [ $? -ne 0 ]; then
            # The script has not spawned a child process, it is probably busy
            # doing something else
            log-debug "No ffmpeg process found running (${ffmpeg_not_running_count})," \
                "script is probably doing something else, stop monitoring for now"
            ((ffmpeg_not_running_count++))
            break
        fi

        # Get CPU utilization of ffmpeg process
        cpu_utilization=$(top -b -n 1 -p "${ffmpeg_pid}" | grep "${ffmpeg_pid}" | awk '{print $9}' | tr ',' '.')

        if [ "$(echo "${cpu_utilization} < ${CPU_THRESHOLD_PERCENT}" | bc)" -eq 1 ]; then
            log-debug "ffmpeg CPU usage (${it}) is below threshold: ${cpu_utilization}"
            ((below_threshold_count++))
        else
            log-debug "ffmpeg CPU usage (${it}) is above threshold: ${cpu_utilization}," \
                "stop monitoring for now"
            break;
        fi

        # Wait for a while before checking CPU utilization again (increase
        # debounce time to make sure the periods of the 2 scripts are not
        # aligned).
        sleep $((DEBOUNCE_PERIOD_SEC + it))
    done

    if [ "${below_threshold_count}" -eq "${DEBOUNCE_COUNT}" ]; then
        # Restart ffmpeg
        log-debug "ffmpeg CPU usage has been below threshold for too long, restarting ffmpeg"
        kill-ffmpeg
        launch-ffmpeg
    elif [ "${ffmpeg_not_running_count}" -eq "${DEBOUNCE_COUNT}" ]; then
        # Restart ffmpeg
        log-debug "ffmpeg has not been seen running for too long, restarting ffmpeg"
        kill-ffmpeg
        launch-ffmpeg
    else
        log-debug "ffmpeg is running and active"
    fi
done

log-error "Script ${SCRIPT_NAME} finished"
exit 0
