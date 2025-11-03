#!/bin/bash

# Script to restart Tor service and fix port conflicts

set -e

echo "Restarting Tor service..."

# Stop Tor services
echo "Stopping Tor services..."
sudo systemctl stop tor 2>/dev/null || true
sudo systemctl stop tor@default 2>/dev/null || true

# Kill any remaining Tor processes
echo "Killing any remaining Tor processes..."
sudo pkill -9 tor 2>/dev/null || true

# Wait a moment for ports to be released
sleep 2

# Check if ports are still in use
if lsof -i :9050 >/dev/null 2>&1 || ss -tuln 2>/dev/null | grep -q ':9050'; then
    echo "⚠ Warning: Port 9050 is still in use. Forcing cleanup..."
    sudo fuser -k 9050/tcp 2>/dev/null || true
    sleep 1
fi

if lsof -i :9012 >/dev/null 2>&1 || ss -tuln 2>/dev/null | grep -q ':9012'; then
    echo "⚠ Warning: Port 9012 is still in use. Forcing cleanup..."
    sudo fuser -k 9012/tcp 2>/dev/null || true
    sleep 1
fi

# Start Tor service
echo "Starting Tor service..."
sudo systemctl start tor

# Wait a moment for Tor to start
sleep 2

# Check status
echo ""
echo "Checking Tor status..."
sudo systemctl status tor --no-pager -l || true

echo ""
echo "Checking if Tor is listening on ports..."
if ss -tuln 2>/dev/null | grep -q ':9050'; then
    echo "✓ Tor is listening on port 9050 (SOCKS)"
else
    echo "⚠ Tor is not listening on port 9050"
fi

if ss -tuln 2>/dev/null | grep -q ':9012'; then
    echo "✓ Tor is listening on port 9012 (OR)"
else
    echo "⚠ Tor is not listening on port 9012"
fi

echo ""
echo "✓ Tor restart complete!"
echo ""
echo "To view Tor logs:"
echo "  sudo journalctl -u tor -f"

