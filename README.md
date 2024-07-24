# devopsfetch
A tool for devops that collects and displays system information, including active ports, user logins, Nginx configurations, Docker images, and container statuses.

## Documentation
1. Installation and Configuration:

- Run `chmod +x install_devopsfetch.sh devopsfetch.sh` to make the scripts executable
- Run `./install_devopsfetch.sh` to install dependencies and set up the systemd service.
- This will install required packages, set up log rotation, and create a systemd service for continuous monitoring.

2. Usage Examples:

- Display active ports: devopsfetch.sh -p
- Display Docker containers: devopsfetch.sh -d
- Display Nginx domains: devopsfetch.sh -n
- Display users and their last login times: devopsfetch.sh -u

3. Logging Mechanism:

- Logs are stored in /var/log/devopsfetch/devopsfetch.log.
- Log rotation is handled by the logrotate configuration set up during installation.

This script covers the installation of necessary dependencies, setting up a systemd service for continuous monitoring, and providing help and documentation. Adjust the monitoring interval and commands as needed for your specific use case.

