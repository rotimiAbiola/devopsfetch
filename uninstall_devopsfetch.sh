#!/bin/bash

set -euo pipefail

log_file="/var/log/uninstall_devopsfetch.log"

# Function to log errors
log_error() {
  echo "[ERROR] $(date): $1" | sudo tee -a "$log_file"
}

# Remove devopsfetch script and systemd service
sudo rm -f /usr/local/bin/devopsfetch || log_error "Failed to remove devopsfetch script"
sudo rm -f /etc/systemd/system/devopsfetch.service || log_error "Failed to remove devopsfetch systemd service file"

# Disable and stop the systemd service
sudo systemctl disable devopsfetch.service || log_error "Failed to disable devopsfetch.service"
sudo systemctl stop devopsfetch.service || log_error "Failed to stop devopsfetch.service"

# Remove log rotation configuration
sudo rm -f /etc/logrotate.d/devopsfetch || log_error "Failed to remove logrotate configuration"

# Optionally remove log files
sudo rm -f /var/log/devopsfetch_output.log || log_error "Failed to remove devopsfetch output log"
sudo rm -f /var/log/devopsfetch_error.log || log_error "Failed to remove devopsfetch error log"

echo "Uninstallation completed. DevOpsFetch and its dependencies have been removed." | sudo tee -a "$log_file"
