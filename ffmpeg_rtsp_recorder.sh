#!/bin/bash
# set -x # Uncomment for debugging

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(realpath "$(dirname "$0")")"
readonly SCRIPT_PID="$$"
readonly LOG_HEADER="$(printf "%-24s - %-5d" ${SCRIPT_NAME} ${SCRIPT_PID})"

_log() {
    echo "$(date +'%Y-%m-%d_%H-%M-%S') [${LOG_HEADER}] $*"
}

log() {
    _log "INFO:  $*"
}

log-error() {
    _log "ERROR: $*"
}

# Function to handle signals
function graceful_exit {
    log-error "Exiting ${SCRIPT_NAME}..."
    exit 0
}

# Set up signal handler for SIGINT (2) (Ctrl+c) and SIGTERM (15) (used by
# systemd & the monitoring script)
trap graceful_exit SIGINT SIGTERM

# To complete with your informations
readonly RTSP_URL="rtsp://username:password@192.168.1.10:554/stream1"
readonly OUTPUT_FILENAME="${SCRIPT_PATH}/securehome_"
readonly RECORDING_DURATION_SEC=1200 # Duration of each recording in seconds
readonly MAX_RECORDINGS=3 # +1 recording files will be kept
readonly FAILURE_COOLDOWN_SEC=900 # Duration to wait in second after a failure to connect to the stream

log-error "Script ${SCRIPT_NAME} started (from ${SCRIPT_PATH}/)"

while true; do
    # Delete older recordings if there are more than MAX_RECORDINGS
    while [ "$(ls -1 "${OUTPUT_FILENAME}"* 2> /dev/null | wc -l)" -gt "${MAX_RECORDINGS}" ]; do
        oldest_recording=$(ls -t "${OUTPUT_FILENAME}"* | tail -n 1)
        log "Removing old recording: ${oldest_recording}"
        if ! rm "${oldest_recording}"; then
            log-error "Failed to remove recording! ${oldest_recording}"
            break;
        fi
    done

    recording_file="${OUTPUT_FILENAME}$(date +'%Y-%m-%d_%H:%M:%S').mp4"
    log "Starting ffmpeg to record for ${RECORDING_DURATION_SEC}s to ${recording_file}"
    # Record the stream. Use -stimeout to disconnect after that many micro
    # seconds if there is a network issue during connection the RTSP stream
    # (here 10 sec)
    ffmpeg \
        -rtsp_transport tcp \
        -i "${RTSP_URL}" \
        -stimeout 10000000 \
        -t "${RECORDING_DURATION_SEC}" \
        -c:v copy \
        -y "${recording_file}" \
        &> /dev/null

    ffmpeg_ret=$?
    log "ffmpeg recording ended with ${ffmpeg_ret}"
    if [ ${ffmpeg_ret} -ne 0 ] && [ ! -e "${recording_file}" ]; then
        log-error "ffmpeg ended with error ${ffmpeg_ret}, waiting" \
            "${FAILURE_COOLDOWN_SEC}s before restarting recording"
        # ffmpeg encountered an error and the recording file does not exists.
        # Most probably this is due to a connection issue, perhaps the stream is
        # not available, so let's wait a bit before trying again.
        sleep ${FAILURE_COOLDOWN_SEC}
    else
        log "Recording created: ${recording_file}"
    fi
done

log-error "Script ${SCRIPT_NAME} finished"
exit 0
