#!/bin/bash

# Function to handle Ctrl+C (SIGINT) signal
function graceful_exit {
    echo "Terminating the ffmpeg script..."
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

while true; do
    # Delete older recordings if there are more than MAX_RECORDINGS
    while [ "$(ls -1 "${OUTPUT_FILENAME}"* | wc -l)" -gt "${MAX_RECORDINGS}" ]; do
        oldest_recording=$(ls -t "${OUTPUT_FILENAME}"* | tail -n 1)
        rm "${oldest_recording}"
    done

    RECORDING_FILE="${OUTPUT_FILENAME}$(date +'%Y-%m-%d_%H:%M:%S').mp4"
    # Record the stream -stimeout to disconnect after that many micro seconds if
    # there is a network issue during connection the RTSP stream (here 10 sec)
    ffmpeg \
        -rtsp_transport tcp \
        -i "${RTSP_URL}" \
        -stimeout 10000000 \
        -t "${RECORDING_DURATION_SEC}" \
        -c:v copy \
        -y "${RECORDING_FILE}" \
        > /dev/null 2>&1

    if [ $? -ne 0 ] && [ ! -e "${RECORDING_FILE}" ]; then
        # ffmpeg encountered an error and the recording file does not exists.
        # Most probably this is due to a connection issue, perhaps the stream is
        # not available, so let's wait a bit before trying again.
        sleep ${FAILURE_COOLDOWN_SEC}
    fi
done
