# ALB Lambda Event Structure Documentation

## Overview

When Application Load Balancer (ALB) invokes a Lambda function, it transforms the HTTP request into a structured event object. This document explains the event structure and how it relates to the payload sent from `call_alb.py`.

## What `call_alb.py` Sends

When you run:
```bash
python call_alb.py my-alb.us-east-1.elb.amazonaws.com "A beautiful sunset"
```

The script sends an HTTP POST request with:
- **URL**: `http://my-alb.us-east-1.elb.amazonaws.com/`
- **Headers**: `Content-Type: application/json`
- **Body** (JSON):
  ```json
  {
    "prompt": "A beautiful sunset"
  }
  ```

## How ALB Transforms It

ALB receives the HTTP request and converts it into an event object with the following structure:

```json
{
  "requestContext": {
    "elb": {
      "targetGroupArn": "arn:aws:elasticloadbalancing:region:account:targetgroup/name/id"
    }
  },
  "httpMethod": "POST",
  "path": "/",
  "queryStringParameters": null,
  "headers": {
    "accept": "application/json",
    "content-type": "application/json",
    "host": "my-alb.us-east-1.elb.amazonaws.com",
    "user-agent": "python-requests/2.31.0",
    "x-amzn-trace-id": "Root=1-..."
  },
  "body": "{\"prompt\": \"A beautiful sunset\"}",
  "isBase64Encoded": false
}
```

## Key Points

1. **`body` is a STRING, not a JSON object**: Even though you sent JSON, ALB stores it as a string in `event['body']`
   - You sent: `{"prompt": "A beautiful sunset"}`
   - Lambda receives: `"{\"prompt\": \"A beautiful sunset\"}"` (as a string)

2. **You must parse the body**: To access your data, you need:
   ```python
   body = json.loads(event['body'])  # Parse the JSON string
   prompt = body['prompt']  # Now access your prompt
   ```

## Event Fields Explained

| Field | Type | Description |
|-------|------|-------------|
| `requestContext.elb.targetGroupArn` | string | ARN of the ALB target group that invoked Lambda |
| `httpMethod` | string | HTTP method: "GET", "POST", "PUT", "DELETE", etc. |
| `path` | string | Request path (e.g., "/", "/api/endpoint") |
| `queryStringParameters` | dict or null | Query parameters from URL (?key=value) |
| `headers` | dict | HTTP request headers (all lowercase keys) |
| `body` | string or null | Request body as a **string** (even if JSON) |
| `isBase64Encoded` | boolean | Whether body is base64 encoded |

## Example: Accessing Your Payload

```python
import json

def lambda_handler(event, context):
    # Check if it's an ALB event
    if 'requestContext' in event and 'elb' in event.get('requestContext', {}):
        # Parse the body (it's a JSON string)
        if event.get('body'):
            body = json.loads(event['body'])
            prompt = body['prompt']  # Your prompt from call_alb.py
            print(f"Prompt: {prompt}")
        
        # Access other fields
        http_method = event['httpMethod']
        path = event['path']
        headers = event['headers']
        query_params = event.get('queryStringParameters')
```

## Query Parameters Example

If you called:
```bash
python call_alb.py my-alb.us-east-1.elb.amazonaws.com "prompt" --query "?debug=true"
```

Then `event['queryStringParameters']` would be:
```python
{
  "debug": "true"
}
```

## Response Format

Lambda must return ALB-compatible response:
```python
{
    'statusCode': 200,
    'statusDescription': '200 OK',
    'isBase64Encoded': False,
    'headers': {
        'Content-Type': 'application/json'
    },
    'body': 'your response body as string'
}
```

## Debugging

The Lambda function has been updated to print the full event structure to CloudWatch Logs. Check the logs to see exactly what ALB sends.



