# devopsfetch
A tool for DevOps Engineers and System Administrators that collects and displays system information, including active ports, user logins, Nginx configurations, Docker images, and container statuses.

## Documentation
1. Installation and Configuration:

- Run `chmod +x install_devopsfetch.sh devopsfetch.sh` to make the scripts executable
- Run `./install_devopsfetch.sh` to install dependencies and set up the systemd service.
- This will install required packages, set up log rotation, and create a systemd service for continuous monitoring.

2. Usage Examples:

- Display active ports: devopsfetch -p
- Display Docker containers: devopsfetch -d
- Display Nginx domains: devopsfetch -n
- Display users and their last login times: devopsfetch -u

3. Logging Mechanism:

- The devopsfetch log will be stored in two files:
    - Output Log: /var/log/devopsfetch_output.log
    - Error Log: /var/log/devopsfetch_error.log
- Log rotation is handled by the logrotate configuration set up during installation.

This script covers the installation of necessary dependencies, setting up a systemd service for continuous monitoring, and providing help and documentation. Adjust the monitoring interval and commands as needed for your specific use case.

