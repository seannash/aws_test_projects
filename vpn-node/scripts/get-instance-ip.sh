#!/bin/bash

# Script to get the public IP address of a Lightsail instance

set -e

INSTANCE_NAME="${1:-tor-node-instance}"
REGION="${2:-us-east-1}"

if [ -z "$1" ]; then
  echo "Usage: $0 [instance-name] [region]"
  echo ""
  echo "Examples:"
  echo "  $0                        # Get IP for 'tor-node-instance' in us-east-1"
  echo "  $0 tor-node-instance      # Get IP for 'tor-node-instance' in us-east-1"
  echo "  $0 tor-node-instance us-west-2  # Get IP for 'tor-node-instance' in us-west-2"
  echo ""
  exit 1
fi

echo "Retrieving public IP for Lightsail instance: $INSTANCE_NAME in region: $REGION"

# Get the instance information
OUTPUT=$(aws lightsail get-instance \
  --instance-name "$INSTANCE_NAME" \
  --region "$REGION" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  if echo "$OUTPUT" | grep -q "NotFoundException"; then
    echo "Error: Instance '$INSTANCE_NAME' not found in Lightsail"
    exit 1
  else
    echo "Error: Failed to retrieve instance information"
    echo "$OUTPUT"
    exit 1
  fi
fi

# Extract the public IP address
PUBLIC_IP=$(echo "$OUTPUT" | jq -r '.instance.publicIpAddress // empty')

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "null" ]; then
  echo "⚠️  Instance found but no public IP address assigned yet"
  echo "   The instance may still be starting up. Please wait a moment and try again."
  exit 1
fi

# Extract instance state
STATE=$(echo "$OUTPUT" | jq -r '.instance.state.name // "unknown"')

echo ""
echo "Instance: $INSTANCE_NAME"
echo "State: $STATE"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "To connect via SSH:"
echo "  ssh -i tor-node-keypair.pem admin@$PUBLIC_IP"
echo ""

