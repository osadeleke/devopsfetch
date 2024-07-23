#!/bin/bash

# Display help message
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-p [PORT]] [-d [CONTAINER]] [-n [DOMAIN]] [-u [USER]] [-t TIME_RANGE]
Information retrieval and monitoring tool for system information.

    -h, --help          display this help and exit
    -p, --port [PORT]   display active ports and services; provide details for a specific port if specified
    -d, --docker [CONTAINER]
                        list Docker images and containers; provide details for a specific container if specified
    -u, --users [USER]  list users and last login times; provide details for a specific user if specified
    -t, --time TIME_RANGE
                        display activities within a specified time range
EOF
}

# Function to create a horizontal line
horizontal_line() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# Display all active ports and services
list_ports() {
    printf "%-10s %-20s %-30s\n" "Port" "Service" "Process"
    horizontal_line
    ss -tuln | awk 'NR>1 {
        split($5, a, ":")
        port = a[length(a)]
        if (port ~ /^[0-9]+$/) {
            print port
        }
    }' | sort -nu | while read -r port; do
        service=$(getent services "$port" | awk '{print $1}')
        process=$(sudo lsof -i :$port -sTCP:LISTEN -t -n -P 2>/dev/null | xargs -r ps -o comm= -p | tr '\n' ',' | sed 's/,$//')
        printf "%-10s %-20s %-30s\n" "$port" "${service:-Unknown}" "${process:-N/A}"
    done
}

# Display detailed information for a specific port
port_details() {
    local port=$1
    
    # Function to check if a string is a valid port number
    is_valid_port() {
        local port=$1
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
            return 0
        else
            return 1
        fi
    }

    # Validate the port number
    if ! is_valid_port "$port"; then
        echo "Invalid port number. Please enter a number between 1 and 65535."
        return 1
    fi

    # Use ss to get port information
    local output=$(sudo ss -tlpn sport = :$port 2>/dev/null)

    # Check if there's any output beyond the header
    if [ "$(echo "$output" | wc -l)" -le 1 ]; then
        echo "No information available for port $port."
    else
        echo "Information for port $port:"
        horizontal_line
        echo "$output" | column -t
    fi
}

# List all Docker images and containers
list_docker() {
    echo "Docker Containers:"
    horizontal_line
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\nDocker Images:"
    horizontal_line
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
}

# Display details for a specific Docker container
docker_details() {
    local container=$1
    echo "Details for Docker Container $container:"
    horizontal_line
    docker inspect "$container" | jq '.[0] | {
        ID: .Id,
        Name: .Name,
        Image: .Config.Image,
        State: .State.Status,
        IPAddress: .NetworkSettings.IPAddress,
        Ports: .NetworkSettings.Ports,
        Mounts: .Mounts
    }' | sed 's/^/  /'
}

# Display all Nginx domains and their ports
list_nginx() {
    echo "Nginx Domains and Ports:"
    echo "------------------------"

    # Find all Nginx configuration files in /etc/nginx
    nginx_files=$(sudo find /etc/nginx -type f -name "*.conf" 2>/dev/null)

    # Find all non-hidden files in sites-available
    sites_available_files=$(sudo find /etc/nginx/sites-available -type f -not -name ".*" 2>/dev/null)

    # Combine the file lists
    config_files="$nginx_files $sites_available_files"

    # Loop through each config file
    for file in $config_files; do
        # Extract server_name (domain) and listen (port) directives
        output=$(sudo awk '
            BEGIN { found = 0 }
            /^\s*server\s*{/,/^\s*}/ {
                if ($1 == "server_name") {
                    for (i=2; i<=NF; i++) {
                        if ($i != ";" && $i != "_") {
                            gsub(/;/, "", $i)
                            print "  Domain:", $i
                            found = 1
                        }
                    }
                }
                if ($1 == "listen") {
                    port = $2
                    gsub(/;/, "", port)
                    if (port ~ /:/) {
                        split(port, a, ":")
                        port = a[2]
                    }
                    if (port ~ /^[0-9]+$/) {
                        print "  Port:", port
                        found = 1
                    }
                }
            }
            END { if (found) print "------------------------" }
        ' "$file")

        # Only print if there's output
        if [ ! -z "$output" ]; then
            echo "$output"
            echo ""
        fi
    done
}


# Display configuration for a specific Nginx domain
nginx_details() {
    local domain=$1
    local nginx_conf_dir="/etc/nginx"
    local sites_available="${nginx_conf_dir}/sites-available"
    local config_file=$(grep -l "server_name\s\+\b${domain}\b" ${sites_available}/* 2>/dev/null)

    if [ -z "$config_file" ]; then
        echo "No configuration found for ${domain}"
        exit 1
    fi

    echo "Configuration for ${domain}:"
    horizontal_line
    awk '/server[[:space:]]*\{/,/^}$/ {
        if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) next;
        if ($0 ~ /^server[[:space:]]*\{/ || $0 ~ /^}$/) next;
        gsub(/^[[:space:]]+/, "");
        print;
    }' "$config_file"
}

# List all users and their last login times
list_users() {
    printf "%-20s %-30s\n" "Username" "Last Login"
    horizontal_line
    lastlog | tail -n +2 | awk '{
        if ($2 == "**Never") 
            printf "%-20s %-30s\n", $1, "Never logged in"
        else if (NF > 3) 
            printf "%-20s %s %s %s %s %s\n", $1, $4, $5, $6, $7, $8
        else 
            printf "%-20s %-30s\n", $1, $2 " " $3
    }' | sort -k3
}

# Display detailed information for a specific user
user_details() {
    local user=$1
    if ! id "$user" &>/dev/null; then
        echo "User does not exist"
        exit 1
    fi

    echo "User Information for: $user"
    horizontal_line

    # Basic user info
    echo "Basic Information:"
    id "$user" | sed 's/^/  /'
    echo

    # Account details
    echo "Account Details:"
    getent passwd "$user" | awk -F: '{split($5,a,","); printf "  Full Name: %s\n  Shell: %s\n", a[1], $7}'
    chage -l "$user" | sed 's/^/  /'
    echo

    # Group membership
    echo "Group Membership:"
    groups "$user" | sed 's/^/  /'
    echo

    # Home directory
    echo "Home Directory:"
    ls -ld "/home/$user" | sed 's/^/  /'
    echo

    # Last login information
    echo "Last Login:"
    lastlog -u "$user" | sed 's/^/  /'
    echo

    # Currently running processes
    echo "Currently Running Processes:"
    ps -u "$user" --format "pid,ppid,%cpu,%mem,start,time,command" | column -t | sed 's/^/  /'
    echo
}

# Display activities within a specified time range
time_range_activities() {
    local time_range=$1
    echo "Activities in the Last $time_range:"
    horizontal_line
    sudo grep "$time_range" /var/log/syslog | awk '{
        printf "%-20s %-15s %-10s %s\n", $1, $2, $3, substr($0, index($0,$4))
    }'
}

# Main script logic
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    while [[ "$1" != "" ]]; do
        case $1 in
            -h | --help )
                show_help
                exit
                ;;
            -p | --port )
                shift
                if [[ -n "$1" ]] && [[ "$1" != "-"* ]]; then
                    port_details "$1"
                else
                    list_ports
                fi
                ;;
            -d | --docker )
                shift
                if [[ -n "$1" ]] && [[ "$1" != "-"* ]]; then
                    docker_details "$1"
                else
                    list_docker
                fi
                ;;
            -n | --nginx )
                shift
                if [[ -n "$1" ]] && [[ "$1" != "-"* ]]; then
                    nginx_details "$1"
                else
                    list_nginx
                fi
                ;;
            -u | --users )
                shift
                if [[ -n "$1" ]] && [[ "$1" != "-"* ]]; then
                    user_details "$1"
                else
                    list_users
                fi
                ;;
            -t | --time )
                shift
                time_range_activities "$1"
                ;;
            * )
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
