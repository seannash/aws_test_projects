#!/bin/bash

# Script to delete an SSH key pair from Lightsail and optionally remove the local private key file

set -e

KEY_PAIR_NAME="${1:-tor-node-keypair}"
REGION="${2:-us-east-1}"
DELETE_LOCAL="${3:-yes}"

if [ -z "$1" ]; then
  echo "Usage: $0 <key-pair-name> [region] [delete-local-yes|no]"
  echo ""
  echo "Examples:"
  echo "  $0 tor-node-keypair                    # Delete keypair in us-east-1, remove local .pem file"
  echo "  $0 tor-node-keypair us-west-2         # Delete keypair in us-west-2, remove local .pem file"
  echo "  $0 tor-node-keypair us-east-1 no       # Delete keypair but keep local .pem file"
  exit 1
fi

echo "Deleting Lightsail key pair: $KEY_PAIR_NAME in region: $REGION"

# Delete the key pair from Lightsail
OUTPUT=$(aws lightsail delete-key-pair \
  --key-pair-name "$KEY_PAIR_NAME" \
  --region "$REGION" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  # Check if the error is because the key pair doesn't exist
  if echo "$OUTPUT" | grep -q "NotFoundException"; then
    echo "⚠️  Key pair '$KEY_PAIR_NAME' not found in Lightsail (may have already been deleted)"
  else
    echo "Error: Failed to delete key pair"
    echo "$OUTPUT"
    exit 1
  fi
else
  echo "✓ Key pair deleted from Lightsail"
fi

# Optionally delete the local private key file
KEY_FILE="${KEY_PAIR_NAME}.pem"
if [ "$DELETE_LOCAL" = "yes" ] || [ "$DELETE_LOCAL" = "y" ]; then
  if [ -f "$KEY_FILE" ]; then
    rm -f "$KEY_FILE"
    echo "✓ Local private key file deleted: $KEY_FILE"
  else
    echo "⚠️  Local private key file not found: $KEY_FILE"
  fi
else
  echo "ℹ️  Local private key file preserved: $KEY_FILE"
fi

echo ""
echo "✓ Deletion complete!"

