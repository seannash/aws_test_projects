#!/bin/bash
# Initialization script for Lightsail instance
# This script runs on first boot to set up the instance

# Immediately create log file to verify script execution
LOG_FILE="/var/log/instance-init.log"
{
    echo "=========================================="
    echo "Instance initialization started at $(date)"
    echo "Script location: $0"
    echo "User: $(whoami)"
    echo "PWD: $(pwd)"
    echo "=========================================="
} > "$LOG_FILE" 2>&1

# Function to log messages
log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# Ensure log directory exists
mkdir -p /var/log
chmod 666 "$LOG_FILE" 2>/dev/null || true

# Continue logging to the file
exec >> "$LOG_FILE" 2>&1

# Function to handle errors gracefully
handle_error() {
    echo "ERROR: Command failed at line $1" >> "$LOG_FILE"
    echo "Continuing with next step..." >> "$LOG_FILE"
    return 0
}

# Don't exit on error, continue execution
set +e
trap 'handle_error $LINENO' ERR

# Update package lists
log "Updating Debian sources to use trixie..."
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/debian.sources 2>&1 | while IFS= read -r line; do log "$line"; done
    log "Sources file updated successfully"
else
    log "Warning: /etc/apt/sources.list.d/debian.sources not found"
fi

log "Updating package lists..."
sudo apt update 2>&1 | while IFS= read -r line; do log "$line"; done

# Full upgrade to trixie
log "Performing full system upgrade to trixie..."
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y 2>&1 | while IFS= read -r line; do log "$line"; done

# Install Tor
log "Installing Tor..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y tor 2>&1 | while IFS= read -r line; do log "$line"; done

# Install obfs4proxy
log "Installing obfs4proxy..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y obfs4proxy 2>&1 | while IFS= read -r line; do log "$line"; done

# Configure Tor
log "Configuring Tor..."
if [ -f /etc/tor/torrc ]; then
    # Create Tor log directory
    sudo mkdir -p /var/log/tor
    sudo chown debian-tor:debian-tor /var/log/tor
    sudo chmod 750 /var/log/tor
    
    {
        echo ""
        echo "# Tor relay configuration"
        echo "ORPort 9013"
        echo "ServerTransportListenAddr obfs4 0.0.0.0:9014"
        echo "ExtORPort auto"
        echo ""
        echo "# Tor logging configuration"
        echo "# Log to file at notice level and above"
        echo "Log notice file /var/log/tor/tor.log"
        echo "# Also log to syslog for system integration"
        echo "Log notice syslog"
        echo "# Log timestamp granularity (1 second)"
        echo "LogTimeGranularity 1"
    } | sudo tee -a /etc/tor/torrc > /dev/null
    
    # Configure logrotate for Tor logs
    log "Configuring logrotate for Tor logs..."
    sudo tee /etc/logrotate.d/tor > /dev/null <<'LOGROTATE_EOF'
/var/log/tor/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 debian-tor debian-tor
    sharedscripts
    postrotate
        systemctl reload tor > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_EOF
    
    log "Tor configuration added successfully"
else
    log "Warning: /etc/tor/torrc not found"
fi

log "=========================================="
log "Instance initialization completed"
log "Rebooting system to apply changes..."
log "=========================================="

# Flush any pending writes
sync

# Reboot the system (give it a moment for logs to flush)
sleep 5
sudo reboot

