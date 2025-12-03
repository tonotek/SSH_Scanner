#!/bin/bash

# MIT License
# TonoTek - Copyright 2025 www.tonotek.com
# Developed for network testing and device discovery in embedded/IoT environments.

# SSH Scanner
# A parallel and robust scanner to find SSH access on IP address ranges, with MAC address and vendor information.
# Note: Use responsibly. Make sure you have permissions to scan the target network.


GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

SSH_TIMEOUT=1
MAX_JOBS=${3:-15}
BUFFER_FILE="/tmp/ssh_scan_buffer_$$.txt"
OUI_FILE="/tmp/oui.txt"

if [ $# -lt 2 ]; then
    echo "Use as: $0 <IP_START> <IP_END> [numero_processi]"
    echo "Example: $0 192.168.1.1 192.168.1.254 15"
    exit 1
fi

START_IP="$1"
END_IP="$2"

cleanup() {
    rm -f "$BUFFER_FILE" 2>/dev/null
}
trap cleanup EXIT

ip_to_int() {
    local ip=$1
    local a b c d
    IFS=. read -r a b c d <<< "$ip"
    echo $((a * 256**3 + b * 256**2 + c * 256 + d))
}

int_to_ip() {
    local num=$1
    echo "$((num >> 24 & 255)).$((num >> 16 & 255)).$((num >> 8 & 255)).$((num & 255))"
}

# SSH Testing (porta 22)
test_ssh() {
    local ip=$1
    local port=22

    ( echo > /dev/tcp/$ip/$port ) &>/dev/null &
    local pid=$!

    ( sleep $SSH_TIMEOUT; kill $pid 2>/dev/null ) &
    local killer=$!

    wait $pid 2>/dev/null
    local result=$?

    kill $killer 2>/dev/null
    wait $killer 2>/dev/null

    if [ $result -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Reverse lookup for DNS resolution
get_hostname() {
    local ip=$1
    local hostname=$(timeout 1 nslookup "$ip" 2>/dev/null | grep "name = " | awk '{print $NF}' | sed 's/\.$//')

    if [ -z "$hostname" ]; then
        echo "---"
    else
        echo "$hostname"
    fi
}

# Mac address lookup
get_mac() {
    local ip=$1

    timeout 0.5 ping -c 1 -W 100 "$ip" &>/dev/null

    local mac=$(arp -n "$ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)

    if [ -z "$mac" ]; then
        mac=$(ip neigh show "$ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
    fi

    if [ -z "$mac" ]; then
        echo "---"
    else
        echo "$mac"
    fi
}

# Single IP tester function
worker() {
    local ip=$1

    if test_ssh "$ip"; then
        hostname=$(get_hostname "$ip")
        mac=$(get_mac "$ip")

        # Scrivi nel buffer
        echo "$ip|$hostname|$mac" >> "$BUFFER_FILE"
    fi
}

# IEEE vendor file OUI download
download_oui() {
    if [ ! -f "$OUI_FILE" ]; then
        echo -e "${BLUE}Scaricando database MAC vendor...${NC}"
        timeout 30 curl -s "https://standards-oui.ieee.org/oui/oui.txt" -o "$OUI_FILE" 2>/dev/null
    fi
}

# IEEE Vendor Lookup
lookup_vendor() {
    local mac=$1

    if [ "$mac" = "---" ] || [ ! -f "$OUI_FILE" ]; then
        echo "---"
        return
    fi

    local mac_prefix=$(echo "$mac" | cut -d: -f1-3 | tr ':' '-' | tr '[:lower:]' '[:upper:]')
    local vendor=$(grep "^$mac_prefix" "$OUI_FILE" 2>/dev/null | head -1 | sed 's/^[^[:space:]]*[[:space:]]*//g' | sed 's/(hex)//g' | xargs)

    if [ -z "$vendor" ]; then
        echo "---"
    else
        echo "$vendor"
    fi
}

START_NUM=$(ip_to_int "$START_IP")
END_NUM=$(ip_to_int "$END_IP")

# Parameters check
if [ $START_NUM -gt $END_NUM ]; then
    echo -e "${YELLOW}Errore: IP iniziale > IP finale${NC}"
    exit 1
fi


clear

echo -e "${YELLOW}=== SSH SCANNER ===${NC}"
echo -e "${YELLOW}Scansione da $START_IP a $END_IP. Attendere prego...${NC}"

progress_file="/tmp/ssh_scan_progress_$$.txt"
echo "0" > "$progress_file"

# Array for process tracing
declare -a pids
job_count=0

# IP Range loop
for ((current=$START_NUM; current<=$END_NUM; current++)); do
    current_ip=$(int_to_ip $current)

    worker_with_progress() {
        local ip=$1
        worker "$ip"
        echo $(($(cat "$progress_file" 2>/dev/null || echo 0) + 1)) > "$progress_file"
    }

    worker_with_progress "$current_ip" &

    pids+=($!)
    ((job_count++))

    if [ $job_count -ge $MAX_JOBS ]; then
        wait -n 2>/dev/null
        ((job_count--))
    fi
done

# Waiting progress bar
total_ips=$((END_NUM - START_NUM + 1))
while [ $(jobs -r | wc -l) -gt 0 ]; do
    completed=$(cat "$progress_file" 2>/dev/null || echo 0)
    percent=$((completed * 100 / total_ips))
    dots=$(printf '%.0s.' $(seq 1 $((percent / 5))))
    empty=$(printf '%.0s ' $(seq 1 $((20 - ${#dots}))))
    echo -ne "\r${dots}${empty} ${percent}%"
    sleep 0.2
done

wait
echo -e "\r$(printf '%.0s.' $(seq 1 20)) 100%"
echo ""

rm -f "$progress_file" 2>/dev/null

# Buffer sort by IP
if [ -f "$BUFFER_FILE" ]; then
    sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$BUFFER_FILE" | while IFS='|' read -r ip hostname mac; do
        vendor=$(lookup_vendor "$mac")
        echo -e "Testing $ip ... ${GREEN}SSH OK${NC} | Host: ${CYAN}$hostname${NC} | MAC: $mac | Vendor: $vendor"
    done
fi

echo ""
