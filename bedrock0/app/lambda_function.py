import json
import boto3
import base64
import datetime
import os

client_bedrock = boto3.client('bedrock-runtime')
client_s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Debug: Print full event structure
    print("=" * 80)
    print("FULL EVENT RECEIVED BY LAMBDA")
    print("=" * 80)
    print(json.dumps(event, indent=2, default=str))
    print()
    
    try:
        # Initialize variables
        input_prompt = None
        body = {}
        
        # Handle ALB events - body comes as a JSON string
        if 'requestContext' in event and 'elb' in event.get('requestContext', {}):
            # ALB event format
            if 'body' in event and event['body']:
                try:
                    body = json.loads(event['body'])
                    input_prompt = body.get('prompt')
                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON body: {e}")
                    return {
                        'statusCode': 400,
                        'statusDescription': '400 Bad Request',
                        'isBase64Encoded': False,
                        'headers': {
                            'Content-Type': 'application/json'
                        },
                        'body': json.dumps({'error': 'Invalid JSON in request body'})
                    }
            else:
                # Fallback to direct prompt in event
                input_prompt = event.get('prompt')
        else:
            # Direct invocation or API Gateway format
            body = event
            input_prompt = event.get('prompt')
        
        if not input_prompt:
            return {
                'statusCode': 400,
                'statusDescription': '400 Bad Request',
                'isBase64Encoded': False,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': 'Prompt is required'})
            }
        
        print(f"Received prompt: {input_prompt}")

        # Use Amazon Titan Image Generator v2
        try:
            # Build request body according to Titan Image Generator v2 API format
            request_body = {
                "taskType": "TEXT_IMAGE",
                "textToImageParams": {
                    "text": input_prompt
                },
                "imageGenerationConfig": {
                    "numberOfImages": 1,
                    "height": 1024,
                    "width": 1024,
                    "cfgScale": 8.0
                }
            }
            
            # Optional parameters for Titan v2
            if 'seed' in body:
                request_body["imageGenerationConfig"]["seed"] = body['seed']
            
            # Prepare invoke_model parameters - use guardrail with no content filtering
            invoke_params = {
                "modelId": 'amazon.titan-image-generator-v2:0',
                "contentType": 'application/json',
                "accept": 'application/json',
                "body": json.dumps(request_body)
            }
            
            # Note: Guardrails are not supported for image generation models like Titan Image Generator v2
            # Attempting to use guardrails with image models results in "input is in incorrect format" error
            # Skip guardrail for image generation models
            guardrail_id = os.environ.get('GUARDRAIL_ID')
            if guardrail_id:
                print(f"Note: Guardrail {guardrail_id} is configured but not used for image generation models")
                print("Guardrails are not supported for Titan Image Generator v2")
            else:
                print("No guardrail ID found in environment variables")
            
            response_bedrock = client_bedrock.invoke_model(**invoke_params)
        except Exception as e:
            print(f"Bedrock error: {str(e)}")
            import traceback
            traceback.print_exc()
            return {
                'statusCode': 500,
                'statusDescription': '500 Internal Server Error',
                'isBase64Encoded': False,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': f'Bedrock error: {str(e)}'})
            }
        
        # Parse Titan Image Generator v2 response format
        try:
            response_bedrock_json = json.loads(response_bedrock['body'].read())
            # Titan Image Generator v2 returns images in images array
            if 'images' in response_bedrock_json and len(response_bedrock_json['images']) > 0:
                # Titan v2 returns images as base64 strings in an array
                response_bedrock_base64 = response_bedrock_json['images'][0]
                response_bedrock_finalimage = base64.b64decode(response_bedrock_base64)
            elif 'image' in response_bedrock_json:
                # Alternative format - single image
                response_bedrock_base64 = response_bedrock_json['image']
                response_bedrock_finalimage = base64.b64decode(response_bedrock_base64)
            else:
                raise ValueError("No image found in response")
        except (KeyError, IndexError, ValueError) as e:
            print(f"Error parsing Bedrock response: {e}")
            print(f"Response structure: {json.dumps(response_bedrock_json, indent=2) if 'response_bedrock_json' in locals() else 'Not parsed'}")
            return {
                'statusCode': 500,
                'statusDescription': '500 Internal Server Error',
                'isBase64Encoded': False,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': f'Error parsing Bedrock response: {str(e)}'})
            }
        print(f"Image generated, size: {len(response_bedrock_finalimage)} bytes")
        
        bucket_name = 'atw-posters-project-2'
        poster_name = 'posterName' + datetime.datetime.today().strftime('%Y-%m-%d-%H-%M-%S')
        
        try:
            response_s3 = client_s3.put_object(
                Bucket=bucket_name,
                Body=response_bedrock_finalimage,
                Key=poster_name
            )
        except Exception as e:
            print(f"S3 error: {str(e)}")
            return {
                'statusCode': 500,
                'statusDescription': '500 Internal Server Error',
                'isBase64Encoded': False,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({'error': f'S3 error: {str(e)}'})
            }
        
        generate_presigned_url = client_s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': poster_name},
            ExpiresIn=3600
        )
        print(f"Presigned URL generated: {generate_presigned_url}")
        
        # Return ALB-compatible response format
        return {
            'statusCode': 200,
            'statusDescription': '200 OK',
            'isBase64Encoded': False,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': generate_presigned_url
        }
        
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'statusDescription': '500 Internal Server Error',
            'isBase64Encoded': False,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': f'Internal error: {str(e)}'})
        }