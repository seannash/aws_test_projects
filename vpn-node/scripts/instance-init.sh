#!/bin/bash

# Exit on any error
set -e

# Install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install wireguard ufw qrencode -y

# Enable IP forwarding
echo "Configuring IP forwarding..."
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Create WireGuard directory if it doesn't exist
sudo mkdir -p /etc/wireguard

# Generate server keys
echo "Generating server keys..."
wg genkey | sudo tee /etc/wireguard/server_private.key
sudo chmod 600 /etc/wireguard/server_private.key
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key

# Generate client keys
echo "Generating client keys..."
wg genkey | sudo tee /etc/wireguard/client_private.key
sudo cat /etc/wireguard/client_private.key | wg pubkey | sudo tee /etc/wireguard/client_public.key

# Get server public IP
SERVER_IP=$(curl http://checkip.amazonaws.com)
SERVER_PRIVATE_KEY=$(sudo cat /etc/wireguard/server_private.key)
CLIENT_PUBLIC_KEY=$(sudo cat /etc/wireguard/client_public.key)

# Create server configuration
echo "Creating server configuration..."
cat << EOF | sudo tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = ufw route allow in on wg0 out on ens5
PostUp = iptables -t nat -I POSTROUTING -o ens5 -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -o ens5 -j MASQUERADE
PostDown = ufw route delete allow in on wg0 out on ens5
PostDown = iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE
PostDown = ip6tables -t nat -D POSTROUTING -o ens5 -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.0.0.2/32
EOF

# Set correct permissions
sudo chmod 600 /etc/wireguard/wg0.conf

# Configure firewall
echo "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 51820/udp
sudo ufw allow OpenSSH
echo "y" | sudo ufw enable

# Create client configuration
echo "Creating client configuration..."
SERVER_PUBLIC_KEY=$(sudo cat /etc/wireguard/server_public.key)
CLIENT_PRIVATE_KEY=$(sudo cat /etc/wireguard/client_private.key)

cat << EOF | sudo tee /etc/wireguard/client.conf
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = 10.0.0.2/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Start WireGuard
echo "Starting WireGuard..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Create directory for client configs
mkdir -p ~/wireguard-client-configs
sudo cp /etc/wireguard/client.conf ~/wireguard-client-configs/
chmod 700 ~/wireguard-client-configs

# Generate QR code
echo "Generating QR code..."
sudo cat /etc/wireguard/client.conf | qrencode -t ansiutf8  > ~/wireguard-client-configs/client-qr.txt

# Print status information
echo "
========================================
WireGuard Installation Complete!
========================================

Server Information:
- Public IP: ${SERVER_IP}
- Port: 51820
- Interface: wg0

Client configuration has been saved to:
~/wireguard-client-configs/client.conf

QR code for mobile clients has been saved to:
~/wireguard-client-configs/client-qr.txt

To check WireGuard status:
sudo wg show

To view the QR code for mobile clients:
cat ~/wireguard-client-configs/client-qr.txt
"

# Show WireGuard status
echo "Current WireGuard status:"
sudo wg show
