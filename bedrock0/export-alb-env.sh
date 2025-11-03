#!/bin/bash
# Script to export ALB DNS name as environment variable from CDK stack

STACK_NAME="Bedrock0Stack"

# Get the ALB DNS name from CloudFormation stack outputs
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDnsName`].OutputValue' \
  --output text 2>/dev/null)

if [ -z "$ALB_DNS" ]; then
  echo "Error: Could not find ALB DNS name in stack $STACK_NAME"
  echo "Make sure the stack is deployed: npx cdk deploy"
  exit 1
fi

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Script is being sourced - export the variable
  export ALB_DNS_NAME="$ALB_DNS"
  echo "✓ ALB_DNS_NAME environment variable has been set: $ALB_DNS_NAME"
else
  # Script is being executed directly - output export command
  echo "ALB DNS name: $ALB_DNS"
  echo ""
  echo "To set as environment variable in current shell, run:"
  echo "  source ./export-alb-env.sh"
  echo ""
  echo "Or eval the output:"
  echo "  eval \$(./export-alb-env.sh | grep '^export')"
  echo ""
  echo "export ALB_DNS_NAME=$ALB_DNS"
fi

