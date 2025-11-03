#!/usr/bin/env python3
"""
Debug script to show what event structure Lambda receives from ALB.
This simulates the event structure that ALB sends to Lambda.
"""

import json

# This is what ALB sends to Lambda when a request is made
alb_event_example = {
    "requestContext": {
        "elb": {
            "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-targets/73e2d6bc24d8c067"
        }
    },
    "httpMethod": "POST",
    "path": "/",
    "queryStringParameters": None,
    "headers": {
        "accept": "application/json",
        "content-type": "application/json",
        "host": "my-alb-1234567890.us-east-1.elb.amazonaws.com",
        "user-agent": "python-requests/2.31.0",
        "x-amzn-trace-id": "Root=1-67890abc-def1-2345-6789-abcdef123456"
    },
    "body": '{"prompt": "A beautiful sunset over mountains"}',  # Note: body is a STRING, not JSON object
    "isBase64Encoded": False
}

print("=" * 80)
print("ALB Event Structure Sent to Lambda")
print("=" * 80)
print(json.dumps(alb_event_example, indent=2))
print()

print("=" * 80)
print("What call_alb.py sends (HTTP Request)")
print("=" * 80)
payload_sent = {
    "prompt": "A beautiful sunset over mountains"
}
print("POST Request Body (JSON):")
print(json.dumps(payload_sent, indent=2))
print()
print("HTTP Headers sent:")
print("  Content-Type: application/json")
print()

print("=" * 80)
print("How Lambda Receives It")
print("=" * 80)
print("1. ALB receives the HTTP request")
print("2. ALB transforms it into an event object")
print("3. The JSON body you sent becomes a STRING in event['body']")
print("4. Lambda needs to parse: json.loads(event['body'])")
print()

print("=" * 80)
print("Key Fields in ALB Event")
print("=" * 80)
print("requestContext.elb.targetGroupArn - The ALB target group")
print("httpMethod - HTTP method (GET, POST, etc.)")
print("path - Request path")
print("queryStringParameters - Query params (dict or None)")
print("headers - HTTP headers (dict)")
print("body - Request body as STRING (even if it's JSON)")
print("isBase64Encoded - Whether body is base64 encoded")
print()

print("=" * 80)
print("To Access Your Prompt")
print("=" * 80)
print("# Parse the body string to get the JSON object")
body_obj = json.loads(alb_event_example['body'])
print(f"Parsed body: {body_obj}")
print(f"Your prompt: {body_obj['prompt']}")



