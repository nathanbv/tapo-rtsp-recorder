#!/bin/bash

# Install script for the Tapo C200 RTSP live video stream recorder service
# Must be root to run this script
# Can be run with custom installation configuration:
# sudo INSTALL_TARGET_USER="${USER}" DEST_PATH="${HOME}/.bin/cam/" LOG_PATH="${HOME}/.bin/cam/logs/" ./install.sh

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(realpath "$(dirname "$0")")"
log() {
    echo "$(date +'%Y-%m-%d_%H:%M:%S') [${SCRIPT_NAME}:$$]: $*"
}

log "Script ${SCRIPT_NAME} started (from ${SCRIPT_PATH}/)"

readonly APP_NAME="tapo-rtsp-recorder"

readonly DEFAULT_DEST_PATH="/usr/bin/${APP_NAME}"
readonly DEST_PATH="${DEST_PATH:-${DEFAULT_DEST_PATH}}"

readonly DEFAULT_LOG_PATH="/var/log/${APP_NAME}"
readonly LOG_PATH="${LOG_PATH:-${DEFAULT_LOG_PATH}}"

readonly DEFAULT_INSTALL_TARGET_USER="root"
readonly INSTALL_TARGET_USER="${INSTALL_TARGET_USER:-${DEFAULT_INSTALL_TARGET_USER}}"

set -euo pipefail

# Make sure script is executed as root
if [[ $(id -u) -ne 0 ]]; then
    log "You must be root to execute this script"
    exit 1
fi

log "Installing: ${APP_NAME}"

# Check if target user exists
if ! getent passwd "${INSTALL_TARGET_USER}" &> /dev/null; then
    log "User ${INSTALL_TARGET_USER} not exists"
    exit 1
else
    log "Installing for user: ${INSTALL_TARGET_USER}"
fi

# Create destination path and copy the content there
log "Installing app files in: ${DEST_PATH}"
mkdir -p "${DEST_PATH}"
cp "${SCRIPT_PATH}/"* "${DEST_PATH}"
chown -R "${INSTALL_TARGET_USER}:${INSTALL_TARGET_USER}" "${DEST_PATH}"

# Create folder for logs
log "Creating logs directory in: ${LOG_PATH}"
mkdir -p "${LOG_PATH}"
chown "${INSTALL_TARGET_USER}:${INSTALL_TARGET_USER}" "${LOG_PATH}"

# Install service
readonly SERVICE_FILE_PATH="/etc/systemd/system/${APP_NAME}.service"
log "Installing service file as: ${SERVICE_FILE_PATH}"
cp "${SCRIPT_PATH}/${APP_NAME}.service" "${SERVICE_FILE_PATH}"
sed -i "s/%LOG_PATH%/$(echo ${LOG_PATH} | sed 's_/_\\/_g')/g" "${SERVICE_FILE_PATH}"
sed -i "s/%DEST_PATH%/$(echo ${DEST_PATH} | sed 's_/_\\/_g')/g" "${SERVICE_FILE_PATH}"
sed -i "s/%INSTALL_TARGET_USER%/$(echo ${INSTALL_TARGET_USER} | sed 's_/_\\/_g')/g" "${SERVICE_FILE_PATH}"

# Start service
log "Enabling service: ${APP_NAME}"
systemctl enable "${APP_NAME}.service"
systemctl daemon-reload

log "Service is installed and can be started with: sudo systemctl start ${APP_NAME}"

log "Script ${SCRIPT_NAME} finished"
exit 0
