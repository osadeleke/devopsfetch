#!/bin/bash

# Script to set up monitoring service and dependencies

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    apt-get update
    apt-get install -y jq docker.io nginx logrotate
}

# Function to create the monitoring script
create_monitor_script() {
    cat << EOF > /usr/local/bin/system_monitor.sh
#!/bin/bash

while true; do
    # Run each monitoring function and log the output
    {
        devopsfetch -p
        echo -e "\n"
        devopsfetch -d
        echo -e "\n"
        devopsfetch -n
        echo -e "\n"
        devopsfetch -u
        echo -e "\n"
        devopsfetch -t
        echo -e "\n"
    } | tee -a /var/log/system_monitor.log

    # Sleep for 24 hours before the next iteration
    sleep 86400
done
EOF

    chmod +x /usr/local/bin/system_monitor.sh
}

# Function to create systemd service
create_systemd_service() {
    cat << EOF > /etc/systemd/system/system-monitor.service
[Unit]
Description=System Monitoring Service
After=network.target

[Service]
ExecStart=/usr/local/bin/system_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable system-monitor.service
    systemctl start system-monitor.service
}

# Function to set up log rotation
setup_log_rotation() {
    cat << EOF > /etc/logrotate.d/system-monitor
/var/log/system_monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
}

# Function to make devopsfetch a command
make_devopsfetch() {
   sudo cp devopsfetch.sh /devopsfetch.sh
   chmod +x /devopsfetch.sh
   sudo ln -s /devopsfetch.sh /usr/local/bin/devopsfetch
}

# Main function
main() {
    check_root
    install_dependencies
    make_devopsfetch
    create_monitor_script
    create_systemd_service
    setup_log_rotation
    
    echo "System monitoring service has been set up and started."
    echo "Logs are stored in /var/log/system_monitor.log"
    echo "Log rotation has been configured."
}

# Run the main function
main
