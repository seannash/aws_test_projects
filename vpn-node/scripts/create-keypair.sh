#!/bin/bash

# Script to create an SSH key pair for Lightsail instance
# This script creates the key pair in Lightsail and saves the private key locally

set -e

KEY_PAIR_NAME="${1:-tor-node-keypair}"
REGION="${2:-us-east-1}"

echo "Creating Lightsail key pair: $KEY_PAIR_NAME in region: $REGION"

# Create the key pair
OUTPUT=$(aws lightsail create-key-pair \
  --key-pair-name "$KEY_PAIR_NAME" \
  --region "$REGION" \
  --output json)

# Extract the private key (field name is misleading - it's actually the PEM content with \n escape sequences)
PRIVATE_KEY=$(echo "$OUTPUT" | jq -r '.privateKeyBase64')

if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "null" ]; then
  echo "Error: Failed to create key pair or retrieve private key"
  echo "Output: $OUTPUT"
  exit 1
fi

# The private key already contains \n escape sequences, jq -r will convert them to actual newlines

# Save the private key to a file
KEY_FILE="${KEY_PAIR_NAME}.pem"
echo "$PRIVATE_KEY" > "$KEY_FILE"

# Set appropriate permissions
chmod 600 "$KEY_FILE"

echo ""
echo "✓ Key pair created successfully!"
echo "✓ Private key saved to: $KEY_FILE"
echo ""
echo "To connect to your instance after deployment, use:"
echo "  ssh -i $KEY_FILE admin@<instance-public-ip>"
echo ""
echo "⚠️  IMPORTANT: Keep your private key secure and never share it!"

