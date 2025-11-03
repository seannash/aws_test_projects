#!/bin/bash

# Script to check and fix Tor service status and port conflicts

set -e

echo "Checking Tor service status..."

# Check if Tor is running
if systemctl is-active --quiet tor; then
    echo "✓ Tor service is running"
    echo "Checking Tor process..."
    TOR_PID=$(pgrep -f tor | head -1)
    if [ -n "$TOR_PID" ]; then
        echo "  Tor process found (PID: $TOR_PID)"
    fi
elif systemctl is-active --quiet tor@default; then
    echo "✓ Tor service (tor@default) is running"
    TOR_PID=$(pgrep -f tor | head -1)
    if [ -n "$TOR_PID" ]; then
        echo "  Tor process found (PID: $TOR_PID)"
    fi
else
    echo "⚠ Tor service is not running"
fi

# Check if port 9050 is in use
echo ""
echo "Checking port 9050..."
if lsof -i :9050 >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ':9050' || ss -tuln 2>/dev/null | grep -q ':9050'; then
    echo "⚠ Port 9050 is in use"
    echo "Finding process using port 9050..."
    
    # Try different methods to find the process
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :9050 || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulnp | grep :9050 || true
    elif command -v ss >/dev/null 2>&1; then
        ss -tulnp | grep :9050 || true
    fi
    
    echo ""
    echo "To fix this, you can:"
    echo "  1. Stop the existing Tor service: sudo systemctl stop tor"
    echo "  2. Or kill the process using port 9050"
else
    echo "✓ Port 9050 is available"
fi

# Check if port 9012 is in use
echo ""
echo "Checking port 9012..."
if lsof -i :9012 >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ':9012' || ss -tuln 2>/dev/null | grep -q ':9012'; then
    echo "⚠ Port 9012 is in use"
    echo "Finding process using port 9012..."
    
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :9012 || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulnp | grep :9012 || true
    elif command -v ss >/dev/null 2>&1; then
        ss -tulnp | grep :9012 || true
    fi
else
    echo "✓ Port 9012 is available"
fi

echo ""
echo "=== Recommended Actions ==="
echo ""
echo "To restart Tor cleanly:"
echo "  1. sudo systemctl stop tor"
echo "  2. sudo systemctl stop tor@default  # if exists"
echo "  3. sudo pkill -9 tor  # kill any remaining Tor processes"
echo "  4. sudo systemctl start tor"
echo "  5. sudo systemctl status tor"
echo ""
echo "Or restart Tor service:"
echo "  sudo systemctl restart tor"

