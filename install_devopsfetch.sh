#!/bin/bash

set -euo pipefail

log_file="/var/log/install_devopsfetch.log"

# Function to log errors
log_error() {
  echo "[ERROR] $(date): $1" | sudo tee -a "$log_file"
}

# Function to detect the operating system
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  else
    log_error "Unsupported OS"
    exit 1
  fi
}

# Function to install dependencies for Debian-based systems
install_debian_dependencies() {
  sudo apt update || log_error "Failed to update package list"
  for pkg in net-tools docker.io nginx; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
      sudo apt install -y $pkg || log_error "Failed to install $pkg"
    else
      echo "$pkg is already installed"
    fi
  done
  sudo usermod -aG docker $USER || log_error "Failed to add user to docker group"
}

# Function to install dependencies for RHEL-based systems
install_rhel_dependencies() {
  sudo yum update -y || log_error "Failed to update package list"
  for pkg in net-tools docker nginx; do
    if ! rpm -q $pkg; then
      sudo yum install -y $pkg || log_error "Failed to install $pkg"
    else
      echo "$pkg is already installed"
    fi
  done
  sudo usermod -aG docker $USER || log_error "Failed to add user to docker group"
}

# Install necessary dependencies based on the detected OS
detect_os
case "$OS" in
  debian|ubuntu)
    install_debian_dependencies
    ;;
  rhel|centos|fedora)
    install_rhel_dependencies
    ;;
  *)
    log_error "Unsupported OS: $OS"
    exit 1
    ;;
esac

# Copy devopsfetch script to /usr/local/bin
sudo cp ./devopsfetch.sh /usr/local/bin/devopsfetch || log_error "Failed to copy devopsfetch to /usr/local/bin/"
sudo chmod +x /usr/local/bin/devopsfetch || log_error "Failed to make devopsfetch executable"

# Create systemd service file
sudo cp ./devopsfetch.service /etc/systemd/system/

# Enable and start the systemd service
sudo systemctl enable devopsfetch.service || log_error "Failed to enable devopsfetch.service"
sudo systemctl start devopsfetch.service || log_error "Failed to start devopsfetch.service"

# Set up log rotation
sudo tee /etc/logrotate.d/devopsfetch > /dev/null <<EOF
/var/log/devopsfetch_output.log /var/log/devopsfetch_error.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload devopsfetch.service > /dev/null 2>/dev/null || true
    endscript
}
EOF

echo "Installation completed. DevOpsFetch is now running and logging to /var/log/devopsfetch_output.log and /var/log/devopsfetch_error.log" | sudo tee -a "$log_file"
