#!/usr/bin/env python3
"""
Script to call the Application Load Balancer endpoint with a prompt.
"""

import sys
import os
import json
import requests

def call_alb(dns_name=None, prompt=None):
    """
    Call the Application Load Balancer endpoint with a prompt.
    
    Args:
        dns_name: The DNS name of the ALB (or set via ALB_DNS_NAME env var)
        prompt: The prompt text to send to the Lambda function
    """
    # Get DNS name from parameter or environment variable
    if not dns_name:
        dns_name = os.environ.get('ALB_DNS_NAME')
    
    if not dns_name:
        print("Error: ALB DNS name not provided.")
        print("\nUsage:")
        print("  python call_alb.py <dns-name> <prompt>")
        print("  or: export ALB_DNS_NAME=<dns-name> && python call_alb.py <prompt>")
        print("\nExample:")
        print("  python call_alb.py my-alb-1234567890.us-east-1.elb.amazonaws.com 'A beautiful sunset over mountains'")
        sys.exit(1)
    
    if not prompt:
        print("Error: Prompt not provided.")
        print("\nUsage:")
        print("  python call_alb.py <dns-name> <prompt>")
        print("\nExample:")
        print("  python call_alb.py my-alb-1234567890.us-east-1.elb.amazonaws.com 'A beautiful sunset over mountains'")
        sys.exit(1)
    
    # Ensure DNS name doesn't have protocol
    if dns_name.startswith('http://'):
        url = dns_name
    elif dns_name.startswith('https://'):
        url = dns_name
    else:
        # Default to HTTP since ALB listener is on port 80
        url = f'http://{dns_name}'
    
    # Prepare the request payload with the prompt
    payload = {
        'prompt': prompt
    }
    
    try:
        print(f"Calling ALB: {url}")
        print(f"Prompt: {prompt}")
        print()
        
        # Send POST request with the prompt in JSON body
        response = requests.post(
            url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=60  # Increased timeout for image generation
        )
        
        print(f"Response Status Code: {response.status_code}")
        print(f"Response Headers:")
        for key, value in response.headers.items():
            print(f"  {key}: {value}")
        
        if response.status_code == 200:
            print("\nResponse Body:")
            try:
                # Try to parse as JSON
                response_json = response.json()
                if isinstance(response_json, dict) and 'body' in response_json:
                    # If body contains a URL, it's likely the presigned S3 URL
                    print(f"Presigned URL: {response_json.get('body', response.text)}")
                else:
                    print(json.dumps(response_json, indent=2))
            except:
                # If not JSON, print as text
                print(response.text)
        else:
            print(f"\nError Response Body:")
            print(response.text)
            print(f"\nError Response (raw bytes):")
            print(response.content)
            # Try to parse as JSON to show structured error
            try:
                error_json = response.json()
                print(f"\nError (parsed JSON):")
                print(json.dumps(error_json, indent=2))
            except:
                pass
            print(f"\n💡 TIP: Check CloudWatch Logs for the Lambda function to see detailed error messages")
        
        return response
        
    except requests.exceptions.RequestException as e:
        print(f"Error calling ALB: {e}")
        sys.exit(1)

if __name__ == '__main__':
    # Parse command line arguments
    # Usage: python call_alb.py <dns-name> <prompt>
    dns_name = None
    prompt = None
    
    if len(sys.argv) >= 2:
        dns_name = sys.argv[1]
    if len(sys.argv) >= 3:
        # Join remaining args as the prompt (in case it contains spaces)
        prompt = ' '.join(sys.argv[2:])
    
    call_alb(dns_name, prompt)

