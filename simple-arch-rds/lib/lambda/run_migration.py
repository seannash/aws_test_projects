import boto3
import json
import os

def handler(event, context):
    request_type = event['RequestType']
    
    # On delete, just return success without running migrations
    if request_type == 'Delete':
        print('Delete request received - skipping migration execution')
        return {
            'Status': 'SUCCESS',
            'Message': 'Stack deletion - no migration executed'
        }
    
    # Handle Create and Update events by running migrations
    ecs_client = boto3.client('ecs')
    
    cluster = os.environ['CLUSTER_NAME']
    task_def = os.environ['TASK_DEFINITION']
    subnets = json.loads(os.environ['SUBNETS'])
    sg = os.environ['SECURITY_GROUP_ID']
    
    print(f'Running migration task in cluster: {cluster}')
    
    response = ecs_client.run_task(
        cluster=cluster,
        taskDefinition=task_def,
        launchType='FARGATE',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': subnets,
                'securityGroups': [sg],
                'assignPublicIp': 'DISABLED'
            }
        },
        startedBy='cdk-migration-trigger'
    )
    
    task_arn = response['tasks'][0]['taskArn']
    print(f'Migration task started: {task_arn}')
    
    # Wait for task to complete (or fail)
    waiter = ecs_client.get_waiter('tasks_stopped')
    waiter.wait(cluster=cluster, tasks=[task_arn])
    
    # Get task details
    task_details = ecs_client.describe_tasks(cluster=cluster, tasks=[task_arn])
    task = task_details['tasks'][0]
    exit_code = task['containers'][0].get('exitCode')
    
    if exit_code == 0:
        print('Migration completed successfully')
        return {
            'Status': 'SUCCESS',
            'TaskArn': task_arn,
            'Message': 'Migration completed successfully'
        }
    else:
        # Get the reason for failure if available
        stop_code = task.get('stopCode', 'UNKNOWN')
        stopped_reason = task.get('stoppedReason', 'Unknown reason')
        
        error_msg = f'Migration task failed with exit code: {exit_code}, stop code: {stop_code}, reason: {stopped_reason}'
        print(f'ERROR: {error_msg}')
        
        # Return success to prevent stack rollback, but include failure details
        return {
            'Status': 'SUCCESS',
            'TaskArn': task_arn,
            'MigrationStatus': 'FAILED',
            'ErrorMessage': error_msg,
            'ExitCode': str(exit_code),
            'StopCode': stop_code,
            'StoppedReason': stopped_reason
        }

