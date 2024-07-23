# Devopsfetch

DevOpsFetch is a tool designed to collect and display system information, including active ports, user logins, Nginx configurations, Docker images, and container statuses. It also implements a systemd service for continuous monitoring and logging of these activities.

## Features

- Information retrieval for:
  - Active ports and services
  - Docker images and containers
  - Nginx domains and configurations
  - User logins and details
  - System activities within specified time ranges
- Continuous monitoring and logging
- Systemd service integration
- Log rotation management

## Installation

1. Clone this repository:
   ```sh
   git clone https://github.com/osadeleke/devopsfetch.git
   cd devopsfetch
   ```
2. Run the setup script:
   ```
   sudo ./setup.sh
   ```
   

   This script (setup.sh) will:
   - Install necessary dependencies
   - Set up the DevOpsFetch tool
   - Create and start a systemd service for continuous monitoring
   - Configure log rotation

## Usage

DevOpsFetch can be used with various command-line flags:

```
devopsfetch [-h] [-p [PORT]] [-d [CONTAINER]] [-n [DOMAIN]] [-u [USER]] [-t TIME_RANGE]
```


### Flags

- `-h, --help`: Display help message and exit
- `-p, --port [PORT]`: Display active ports and services; provide details for a specific port if specified
- `-d, --docker [CONTAINER]`: List Docker images and containers; provide details for a specific container if specified
- `-n, --nginx [DOMAIN]`: Display Nginx domains and ports; provide configuration for a specific domain if specified
- `-u, --users [USER]`: List users and last login times; provide details for a specific user if specified
- `-t, --time TIME_RANGE`: Display activities within a specified time range

### Examples

1. List all active ports:
   ```
   devopsfetch -p
   ```

2. Get details for a specific port:
   ```
   devopsfetch -p 80
   ```

3. List all Docker containers and images:
   ```
   devopsfetch -d
   ```

4. Get details for a specific Docker container:
   ```
   devopsfetch -d my_container
   ```

5. List all Nginx domains:
   ```
   devopsfetch -n
   ```

6. Get configuration for a specific Nginx domain:
   ```
   devopsfetch -n example.com
   ```

7. List all users and their last login times:
   ```
   devopsfetch -u
   ```

8. Get details for a specific user:
   ```
   devopsfetch -u username
   ```

9. Display activities in the last hour:
   ```
   devopsfetch -t "1 hour ago"
   ```

## Continuous Monitoring

The setup script (setup.sh) creates a systemd service that runs Devopsfetch continuously, logging the output to `/var/log/system_monitor.log`. The service runs the monitoring script every 24 hours.

To check the status of the monitoring service:

```
sudo systemctl status system-monitor
```

## Logging

Logs are stored in `/var/log/system_monitor.log`. Log rotation is configured to manage log file sizes and retention.

To view the logs:

```
sudo tail -f /var/log/system_monitor.log
```

## Customization

You can modify the monitoring interval by editing the `system_monitor.sh` script created by the setup script. Look for the `sleep 86400` command and adjust the value as needed (in seconds).

## Troubleshooting

If you encounter any issues:

1. Check the systemd service status:
   ```
   sudo systemctl status system-monitor
   ```

2. Review the logs:
   ```
   sudo journalctl -u system-monitor
   ```

3. Ensure all dependencies are correctly installed:
   ```
   sudo apt-get install -y jq docker.io nginx logrotate
   ```

## Contributing

Contributions are welcome! Please, feel free to submit a Pull Request.
