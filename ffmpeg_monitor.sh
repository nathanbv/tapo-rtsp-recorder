#!/bin/bash

ffmpeg_script_pid=0
readonly FFMPEG_SCRIPT="./ffmpeg_rtsp_recorder.sh" # Path to the script using ffmpeg

kill-ffmpeg() {
    # Forcefully terminate ffmpeg process
    ffmpeg_pid=$(pgrep --parent ${ffmpeg_script_pid})
    kill -9 ${ffmpeg_pid}

    kill -9 ${ffmpeg_script_pid}
}

launch-ffmpeg() {
    # Start the ffmpeg recording script in the background
    bash "${FFMPEG_SCRIPT}" &

    # Get the PID of the most recently started ffmpeg process
    ffmpeg_script_pid=$!
}

# Function to handle Ctrl+C (SIGINT) signal
function graceful_exit {
    echo "Terminating the monitor script..."
    kill-ffmpeg
    exit 0
}

# Set up signal handler for SIGINT
trap graceful_exit SIGINT

readonly CPU_THRESHOLD_PERCENT=2
readonly MONITOR_PERIOD_SEC=300 # Period at which the ffmpeg script will be monitored
readonly DEBOUNCE_COUNT=10
readonly DEBOUNCE_PERIOD_SEC=3

# Initially start ffmpeg
launch-ffmpeg

while true; do
    # Wait for a while before checking CPU utilization
    sleep ${MONITOR_PERIOD_SEC}

    below_threshold_count=0
    for ((i=1; i<=DEBOUNCE_COUNT; i++)); do
        # Wait for a while before checking CPU utilization
        sleep ${DEBOUNCE_PERIOD_SEC}

        # Try to find the ffmpeg process spawned by the script
        ffmpeg_pid=$(pgrep --parent ${ffmpeg_script_pid})
        if [ $? -ne 0 ]; then
            # The script has not spawned a child process, it is probably busy
            # doing something else
            break
        fi

        # Get CPU utilization of ffmpeg process
        cpu_utilization=$(top -b -n 1 -p ${ffmpeg_pid} | grep "${ffmpeg_pid}" | awk '{print $9}' | tr ',' '.')

        if [ "$(echo "$cpu_utilization < $CPU_THRESHOLD_PERCENT" | bc)" -eq 1 ]; then
            ((below_threshold_count++))
        fi
    done

    if [ "$below_threshold_count" -eq "$DEBOUNCE_COUNT" ]; then
        # Restart ffmpeg
        kill-ffmpeg
        launch-ffmpeg
    fi
done
