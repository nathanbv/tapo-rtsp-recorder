#!/bin/bash
# set -x # Uncomment for debugging

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(realpath "$(dirname "$0")")"
log() {
    echo "$(date +'%Y-%m-%d_%H:%M:%S') [${SCRIPT_NAME}:$$]: $*"
}

# Function to handle Ctrl+C (SIGINT) signal
function graceful_exit {
    log "Exiting ${SCRIPT_NAME}..."
    exit 0
}

# Set up signal handler for SIGINT
trap graceful_exit SIGINT

# To complete with your informations
readonly RTSP_URL="rtsp://username:password@192.168.1.10:554/stream1"
readonly OUTPUT_FILENAME="securehome_"
readonly RECORDING_DURATION_SEC=900 # Duration of each recording in seconds
readonly MAX_RECORDINGS=2 # +1 recording files will be kept
readonly FAILURE_COOLDOWN_SEC=1800 # Duration to wait in second after a failure to connect to the stream

log "Script ${SCRIPT_NAME} started (from ${SCRIPT_PATH}/)"

while true; do
    # Delete older recordings if there are more than MAX_RECORDINGS
    while [ "$(ls -1 "${OUTPUT_FILENAME}"* 2> /dev/null | wc -l)" -gt "${MAX_RECORDINGS}" ]; do
        oldest_recording=$(ls -t "${OUTPUT_FILENAME}"* | tail -n 1)
        log "Removing old recording: ${oldest_recording}"
        if ! rm "${oldest_recording}"; then
            log "Failed to remove recording!"
            break;
        fi
    done

    recording_file="${OUTPUT_FILENAME}$(date +'%Y-%m-%d_%H:%M:%S').mp4"
    log "Starting ffmpeg to record for ${RECORDING_DURATION_SEC}s to ${recording_file}"
    # Record the stream -stimeout to disconnect after that many micro seconds if
    # there is a network issue during connection the RTSP stream (here 10 sec)
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
        log "ffmpeg ended with error ${ffmpeg_ret}, waiting ${FAILURE_COOLDOWN_SEC}s" \
            "before restarting recording"
        # ffmpeg encountered an error and the recording file does not exists.
        # Most probably this is due to a connection issue, perhaps the stream is
        # not available, so let's wait a bit before trying again.
        sleep ${FAILURE_COOLDOWN_SEC}
    fi
done

log "Script ${SCRIPT_NAME} finished"
exit 0
