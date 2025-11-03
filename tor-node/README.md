# Tor Node - AWS Lightsail CDK Stack

This AWS CDK project deploys a Tor relay node on Amazon Lightsail with automatic configuration and logging.

## Overview

This project creates an Amazon Lightsail instance configured as a Tor relay node with:
- **512MB RAM, 2 vCPU, 20GB SSD, 1 TB Transfer**
- **Debian 12** (upgraded to Debian 13/Trixie during initialization)
- **Tor relay** with obfs4 transport support
- **Static IP address** for consistent connectivity
- **Automatic logging** to `/var/log/tor/tor.log`
- **Firewall rules** configured for Tor ports

## Features

- **Automated setup**: Initialization script configures Tor automatically on first boot
- **Tor relay configuration**: OR port 9013, obfs4 transport on port 9014
- **Persistent logging**: Tor logs saved to disk with automatic rotation
- **Static IP**: Instance maintains the same IP address
- **Helper scripts**: Tools for managing SSH keys, checking instance status, and troubleshooting

## Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials (`aws configure`)
- **Node.js** (v18 or later) and npm installed
- **AWS CDK CLI** installed (`npm install -g aws-cdk`)
- **jq** installed (for helper scripts)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Create SSH Key Pair

Before deploying, create an SSH key pair in Lightsail:

```bash
./scripts/create-keypair.sh tor-node-keypair us-east-1
```

This will:
- Create the key pair in Lightsail
- Save the private key as `tor-node-keypair.pem` locally
- Set proper permissions (600) on the private key

**Important:** Keep your private key secure and never commit it to version control!

### 3. Build the Project

```bash
npm run build
```

### 4. Deploy the Stack

```bash
npx cdk deploy
```

This will create:
- Lightsail instance with Tor configuration
- Static IP address attached to the instance
- Firewall rules for SSH (22), OR port (9013), and obfs4 port (9014)

### 5. Get Instance IP Address

```bash
# Using the helper script (recommended)
./scripts/get-instance-ip.sh

# Or using AWS CLI directly
aws lightsail get-instance --instance-name tor-node-instance --query 'instance.publicIpAddress' --output text
```

### 6. Connect to Instance

```bash
ssh -i tor-node-keypair.pem admin@<instance-public-ip>
```

## Instance Configuration

### Initialization Script

The instance runs an initialization script on first boot that:

1. Updates Debian sources from bookworm to trixie
2. Upgrades the system to Debian 13 (Trixie)
3. Installs Tor and obfs4proxy
4. Configures Tor relay settings:
   - ORPort: 9013
   - obfs4 transport: 9014
   - ExtORPort: auto
5. Sets up logging to `/var/log/tor/tor.log`
6. Configures log rotation
7. Reboots to apply changes

### Tor Configuration

Tor is configured as a relay node with:
- **OR Port**: 9013 (for Tor network connections)
- **obfs4 Transport**: Port 9014 (for obfuscated connections)
- **Logging**: Notice level and above saved to `/var/log/tor/tor.log`
- **Log Rotation**: Daily rotation, keeps 7 days of logs

### Firewall Rules

The Lightsail firewall is configured to allow:
- **Port 22**: SSH access
- **Port 9013**: Tor OR port (relay connections)
- **Port 9014**: obfs4 transport (obfuscated connections)

## Helper Scripts

### SSH Key Management

- **`scripts/create-keypair.sh`**: Create a new SSH key pair
  ```bash
  ./scripts/create-keypair.sh [key-pair-name] [region]
  ```

- **`scripts/delete-keypair.sh`**: Delete a key pair
  ```bash
  ./scripts/delete-keypair.sh [key-pair-name] [region] [delete-local-yes|no]
  ```

### Instance Management

- **`scripts/get-instance-ip.sh`**: Get the instance public IP address
  ```bash
  ./scripts/get-instance-ip.sh [instance-name] [region]
  ```

- **`scripts/check-tor-ports.sh`**: Check Tor service status and port usage
  ```bash
  ./scripts/check-tor-ports.sh
  ```

- **`scripts/restart-tor.sh`**: Restart Tor service and fix port conflicts
  ```bash
  ./scripts/restart-tor.sh
  ```

## Monitoring and Logs

### View Tor Logs

```bash
# View current logs
sudo cat /var/log/tor/tor.log

# Follow logs in real-time
sudo tail -f /var/log/tor/tor.log

# View via journalctl
sudo journalctl -u tor -f
```

### Check Tor Status

```bash
# Service status
sudo systemctl status tor

# Check if Tor is listening on ports
sudo ss -tuln | grep -E ':(9013|9014)'
```

### Instance Initialization Logs

```bash
# View initialization script logs
cat /var/log/instance-init.log

# View cloud-init logs
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/cloud-init.log
```

## Troubleshooting

### Initialization Script Not Running

If the initialization script doesn't run:

1. Check cloud-init logs:
   ```bash
   sudo cat /var/log/cloud-init-output.log
   sudo cat /var/log/cloud-init.log
   ```

2. Verify userData was passed:
   ```bash
   aws lightsail get-instance --instance-name tor-node-instance --query 'instance.userData' --output text
   ```

3. Note: UserData only runs on first boot. If the instance already exists, create a new instance.

### Tor Not Starting

1. Check Tor status:
   ```bash
   sudo systemctl status tor
   ```

2. Check for port conflicts:
   ```bash
   ./scripts/check-tor-ports.sh
   ```

3. Restart Tor:
   ```bash
   ./scripts/restart-tor.sh
   ```

4. Check Tor configuration:
   ```bash
   sudo tor --verify-config -f /etc/tor/torrc
   ```

### Port Binding Issues

If Tor can't bind to ports:

1. Check firewall rules in Lightsail console
2. Verify ports are open:
   ```bash
   sudo ss -tuln | grep -E ':(9013|9014)'
   ```
3. Check if ports are in use:
   ```bash
   sudo lsof -i :9013
   sudo lsof -i :9014
   ```

## Project Structure

```
tor-node/
├── bin/
│   └── tor-node.ts          # CDK app entry point
├── lib/
│   └── tor-node-stack.ts    # Main stack definition
├── scripts/
│   ├── create-keypair.sh    # Create SSH key pair
│   ├── delete-keypair.sh    # Delete SSH key pair
│   ├── get-instance-ip.sh   # Get instance IP address
│   ├── instance-init.sh     # Instance initialization script
│   ├── check-tor-ports.sh   # Check Tor ports
│   └── restart-tor.sh       # Restart Tor service
├── test/
│   └── tor-node.test.ts     # Unit tests
├── package.json
├── tsconfig.json
└── README.md
```

## Configuration

### Customizing Instance Properties

Edit `lib/tor-node-stack.ts` to modify:
- Instance bundle (RAM, CPU, disk)
- Instance name
- Static IP name
- Firewall rules

### Customizing Tor Configuration

Edit `scripts/instance-init.sh` to modify:
- Tor ports
- Logging settings
- Additional packages to install

## Security Considerations

- **SSH Access**: Consider restricting SSH (port 22) to your IP address in production
- **Private Keys**: Never commit `.pem` files to version control
- **Tor Relay**: Running a Tor relay exposes your IP address. Understand the implications
- **Logging**: Logs may contain sensitive information; review and secure appropriately

## Cost

- **Lightsail Instance**: ~$3.50/month (nano_3_0 bundle)
- **Static IP**: Free when attached to an instance
- **Data Transfer**: 1 TB included per month

## Useful Commands

```bash
# CDK Commands
npm run build          # Compile TypeScript to JavaScript
npm run watch          # Watch for changes and compile
npm run test           # Run unit tests
npx cdk deploy         # Deploy stack to AWS
npx cdk diff           # Compare deployed stack with current state
npx cdk synth          # Synthesize CloudFormation template
npx cdk destroy        # Destroy the stack

# AWS CLI Commands
aws lightsail get-instance --instance-name tor-node-instance
aws lightsail get-static-ips
aws lightsail get-instance-access-details --instance-name tor-node-instance --protocol ssh
```

## Resources

- [AWS Lightsail Documentation](https://docs.aws.amazon.com/lightsail/)
- [Tor Project Documentation](https://www.torproject.org/docs/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)

## License

This project is provided as-is for educational and research purposes.

## Support

For issues related to:
- **AWS Lightsail**: Check AWS documentation or support
- **Tor**: Check Tor project documentation
- **CDK**: Check AWS CDK documentation

---

**Note**: Running a Tor relay may have legal and ethical implications. Ensure you understand local laws and regulations before deploying.
