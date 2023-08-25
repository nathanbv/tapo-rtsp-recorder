#!/bin/bash

# Function to handle Ctrl+C (SIGINT) signal
function graceful_exit {
    echo "Terminating the ffmpeg script..."
    exit 0
}

# Set up signal handler for SIGINT
trap graceful_exit SIGINT

# To complete with your informations
RTSP_URL="rtsp://username:password@192.168.1.10:554/stream1"
OUTPUT_FILENAME="securehome_"
DURATION_SEC=900 # Duration of each recording in seconds
MAX_RECORDINGS=2 # +1 recording files will be kept

while true; do
    # Delete older recordings if there are more than MAX_RECORDINGS
    while [ "$(ls -1 "${OUTPUT_FILENAME}"* | wc -l)" -gt "${MAX_RECORDINGS}" ]; do
        oldest_recording=$(ls -t "${OUTPUT_FILENAME}"* | tail -n 1)
        rm "${oldest_recording}"
    done

    TIMESTAMP=$(date +'%Y-%m-%d_%H:%M:%S')
    # Record the stream -stimeout to disconnect after that many micro seconds if
    # there is a network issue during connection the RTSP stream (here 10 sec)
    ffmpeg \
        -rtsp_transport tcp \
        -i "${RTSP_URL}" \
        -stimeout 10000000 \
        -t "${DURATION_SEC}" \
        -c:v copy \
        -y "${OUTPUT_FILENAME}${TIMESTAMP}.mp4" \
        > /dev/null 2>&1
done
