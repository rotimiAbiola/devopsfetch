#!/bin/bash

set -e

# Function that provides help on how to use the script
usage() {
  cat <<USAGE
Usage: ${0##*/} [OPTIONS]

Options:
  -p, --port [PORT]       Display all active ports or detailed information about a specific port.
  -d, --docker [CONTAINER] List all Docker images and containers or detailed information about a specific container.
  -n, --nginx [DOMAIN]    Display all Nginx domains and their ports or detailed configuration information for a specific domain.
  -u, --users [USERNAME]  List all users and their last login times or detailed information about a specific user.
  -t, --time [RANGE]      Display activities within a specified time range.
  -h, --help      Show this help message and exit

Examples:
  ${0##*/} -p
  ${0##*/} -p 80
  ${0##*/} -d
  ${0##*/} -d my_container
  ${0##*/} -n
  ${0##*/} -n example.com
  ${0##*/} -u
  ${0##*/} -u udofort
  ${0##*/} -t "2024-07-01 00:00:00 to 2024-07-23 23:59:59"

USAGE
}

# Function to display all active ports and their services
display_ports() {
    printf "%-10s %-20s %-30s\n" "Port" "Service" "User"
    echo "--------------------------------------------------------------"

    netstat -tuln | awk 'NR>2 {
        split($4, a, ":")
        port = a[length(a)]
        if (port ~ /^[0-9]+$/) {
            print port
        }
    }' | sort -nu | while read -r port; do
        service=$(getent services "$port" | awk '{print $1}')
        if [ -z "$service" ]; then
            service="Unknown"
        fi
        user=$(sudo lsof -i :$port -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {print $3}' | sort -u | tr '\n' ',' | sed 's/,$//')
        if [ -z "$user" ]; then
            user="N/A"
        fi
        printf "%-10s %-20s %-30s\n" "$port" "$service" "$user"
    done
}

# Function to display detailed information about a specific port
detailed_port_info() {
    local port=$1
    printf "%-15s %-25s\n" "Field" "Value"
    echo "---------------------------------------"

    # Get service name
    service=$(getent services "$port" | awk '{print $1}')
    if [ -z "$service" ]; then
        service="Unknown"
    fi

    # Get processes listening on the port
    process_info=$(sudo lsof -i :$port -sTCP:LISTEN -n -P 2>/dev/null | awk '{print $2, $3, $9, $10}' | column -t)
    if [ -z "$process_info" ]; then
        process_info="No process is listening on this port"
    fi

    printf "%-15s %-25s\n" "Port" "$port"
    printf "%-15s %-25s\n" "Service" "$service"
    echo -e "\n\nProcess Info:"
    echo "$process_info"
}

# Function to list all Docker images and containers
list_docker_info() {
    printf "%-20s %-50s %-10s\n" "Type" "Name/ID" "Status"
    echo "-----------------------------------------------------------------------------------"

    # List Docker images
    sudo docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | while read -r image; do
        printf "%-20s %-50s %-10s\n" "Image" "$image" "N/A"
    done

    # List Docker containers
    sudo docker ps -a --format "{{.Names}} {{.ID}} {{.Status}}" | while read -r container; do
        name=$(echo $container | awk '{print $1}')
        id=$(echo $container | awk '{print $2}')
        status=$(echo $container | awk '{print $3}')
        printf "%-20s %-50s %-10s\n" "Container" "$name ($id)" "$status"
    done
}

# Function to display detailed information about a specific Docker container
detailed_container_info() {
    local container_name=$1
    container_info=$(sudo docker inspect $container_name)

    if [ -z "$container_info" ]; then
        echo "No such container: $container_name"
        exit 1
    fi

    echo "$container_info" | jq -r '.[] | to_entries | .[] | "\(.key) \(.value)"' | while read -r line; do
        key=$(echo $line | awk '{print $1}')
        value=$(echo $line | awk '{$1=""; print $0}')
        printf "%-20s %-50s\n" "$key" "$value"
    done
}

# Function to list all Nginx domains and their ports
list_nginx_domains() {
    printf "%-30s %-30s %-50s\n" "Domain" "Proxy/Port" "Config File"
    echo "-----------------------------------------------------------------------------------------------------"

    temp_file=$(mktemp)

    for file in /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*; do
        if [[ -f $file ]]; then
            domains=$(grep -E 'server_name' "$file" | awk '{for (i=2; i<=NF; i++) print $i}' | tr -d ';')
            proxy=$(grep -E 'proxy_pass' "$file" | awk '{print $2}' | tr -d ';')
            if [ -z "$proxy" ]; then
                port=$(grep -E 'listen' "$file" | awk '{print $2}' | tr -d ';')
                proxy="http://localhost:$port"
            fi
            for domain in $domains; do
                printf "%-30s %-30s %-50s\n" "$domain" "$proxy" "$file" >> "$temp_file"
            done
        fi
    done

    tail -n 6 "$temp_file"
    rm -f "$temp_file"
}

# Function to display detailed information about a specific Nginx domain
detailed_domain_info() {
    local domain=$1
    found=false
    for file in /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*; do
        if [[ -f $file ]]; then
            if grep -q "server_name.*\b$domain\b" "$file"; then
                config_file=$file
                if [[ $file == /etc/nginx/sites-enabled/* && -L $file ]]; then
                    linked_file=$(readlink -f $file)
                    if [[ $linked_file == /etc/nginx/sites-available/* ]]; then
                        config_file=$linked_file
                    fi
                fi
                found=true
                echo "Config File: $config_file"
                echo "-------------------------------------------------------------------"
                grep -vE '^\s*#' "$config_file" | sed 's/^/    /'
                echo
                break
            fi
        fi
    done

    if ! $found; then
        echo "No such domain: $domain"
    fi
}

# Function to list all regular users and their last login times
list_users() {
    printf "%-20s %-30s %-20s\n" "Username" "Last Login" "Login IP"
    echo "--------------------------------------------------------------"

    awk -F':' '{ if ($3 >= 1000 && $1 != "nobody") print $1 }' /etc/passwd | while read -r user; do
        last_login=$(last -n 1 "$user" | head -n 1 | awk '{print $4, $5, $6, $7, $8}')
        login_ip=$(last -n 1 "$user" | head -n 1 | awk '{print $3}')
        if [ -z "$last_login" ]; then
            last_login="Never logged in"
        fi
        if [ -z "$login_ip" ]; then
            login_ip="N/A"
        fi
        printf "%-20s %-30s %-20s\n" "$user" "$last_login" "$login_ip"
    done
}

# Function to display detailed information about a specific user
detailed_user_info() {
    local username=$1
    if id "$username" &>/dev/null; then
        user_info=$(getent passwd "$username")
        IFS=':' read -r username passwd uid gid gecos home shell <<< "$user_info"

        if (( uid < 1000 )); then
            echo "No such regular user: $username"
            return
        fi

        last_login=$(last -n 1 "$username" | head -n 1 | awk '{print $4, $5, $6, $7, $8}')
        login_ip=$(last -n 1 "$username" | head -n 1 | awk '{print $3}')
        if [ -z "$last_login" ]; then
            last_login="Never logged in"
        fi
        if [ -z "$login_ip" ]; then
            login_ip="N/A"
        fi

        password_expiry=$(chage -l "$username" | grep "Password expires" | awk -F': ' '{print $2}')

        printf "%-15s %-20s %-15s %-25s %-30s %-20s %-25s\n" "Username" "User ID" "Group ID" "Groups" "Last Login" "Last Login IP" "Password Expiry"
        echo "---------------------------------------------------------------------------------------------------------------------------------------"
        printf "%-15s %-20s %-15s %-25s %-30s %-20s %-25s\n" "$username" "$uid" "$gid" "$last_login" "$login_ip" "$password_expiry"
    else
        echo "No such user: $username"
    fi
}

# Function to display activities within a specified time range
display_activities_in_time_range() {
    local start_date=$1
    local end_date=$2

    if [ -z "$end_date" ]; then
        end_date=$(date -I -d "$start_date + 1 day")
    fi

    if ! date -d "$start_date" >/dev/null 2>&1 || ! date -d "$end_date" >/dev/null 2>&1; then
        echo "Invalid date format. Please use YYYY-MM-DD."
        exit 1
    fi

    echo "Activities from $start_date to $end_date"
    echo "--------------------------------------------------------------------------------------------------------------------------------------"
    journalctl --since="$start_date" --until="$end_date"
}

continuous_monitoring() {
    log_file="/var/log/devopsfetch.log"
    while true; do
        echo "Monitoring activities at $(date)" >> "$log_file"
        echo "Ports:" >> "$log_file"
        display_ports >> "$log_file"
        echo "Users:" >> "$log_file"
        list_users >> "$log_file"
        echo "Docker Info:" >> "$log_file"
        list_docker_info >> "$log_file"
        echo "Nginx Domains:" >> "$log_file"
        list_nginx_domains >> "$log_file"
        echo "-------------------------------------------------------------------" >> "$log_file"
        sleep 60  # Run every minute
    done
}

# Handle continuous monitoring mode
if [ "$1" == "--monitor" ]; then
    continuous_monitoring
    exit 0
fi


case $1 in
    -p|--port)
        if [ -z "$2" ]; then
            display_ports
        elif [[ "$2" =~ ^[0-9]+$ ]]; then
            detailed_port_info "$2"
        else
            echo "Invalid port number. Please provide a valid port number."
            exit 1
        fi
        ;;
    -d|--docker)
        if [ -z "$2" ]; then
            list_docker_info
        else
            detailed_container_info "$2"
        fi
        ;;
    -n|--nginx)
        if [ -z "$2" ]; then
            list_nginx_domains
        else
            detailed_domain_info "$2"
        fi
        ;;
    -u|--users)
        if [ -z "$2" ]; then
            list_users
        else
            detailed_user_info "$2"
        fi
        ;;
    -t|--time)
        if [ -z "$2" ]; then
            echo "Please provide a start date in YYYY-MM-DD format."
            exit 1
        elif [ -z "$3" ]; then
            display_activities_in_time_range "$2"
        else
            display_activities_in_time_range "$2" "$3"
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
