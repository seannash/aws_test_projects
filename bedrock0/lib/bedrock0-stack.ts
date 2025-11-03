import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as targets from 'aws-cdk-lib/aws-elasticloadbalancingv2-targets';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as bedrock from 'aws-cdk-lib/aws-bedrock';
import * as path from 'path';

export class Bedrock0Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create S3 bucket for posters
    const postersBucket = new s3.Bucket(this, 'PostersBucket', {
      bucketName: 'atw-posters-project-2',
    });

    // Use existing guardrail
    const existingGuardrailArn = 'arn:aws:bedrock:us-east-1:917324047519:guardrail/nkcpdqqgdifk';
    const existingGuardrailId = 'nkcpdqqgdifk';

    // Create VPC for ALB (ALB requires VPC)
    const vpc = new ec2.Vpc(this, 'BedrockVpc', {
      maxAzs: 2,
      natGateways: 0, // Use public subnets only to save costs
    });

    // Create IAM role for Lambda with Bedrock access
    const lambdaRole = new iam.Role(this, 'LambdaRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
      inlinePolicies: {
        BedrockAccess: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                'bedrock:InvokeModel',
                'bedrock:InvokeModelWithResponseStream',
                'bedrock:ListFoundationModels',
                'bedrock:GetGuardrail',
                'bedrock:UseGuardrails',
                'bedrock:ApplyGuardrail',
              ],
              resources: [
                "*",
              ],
            }),
          ],
        }),
        S3WriteAccess: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                's3:PutObject',
                's3:PutObjectAcl',
                's3:GetObject',
                's3:DeleteObject',
              ],
              resources: ['arn:aws:s3:::*/*'],
            }),
          ],
        }),
      },
    });

    // Create Lambda function from Python code in app directory
    const lambdaFunction = new lambda.Function(this, 'BedrockLambda', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'lambda_function.lambda_handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '../app')),
      role: lambdaRole,
      timeout: cdk.Duration.seconds(60), // Increased for image generation
      environment: {
        GUARDRAIL_ID: existingGuardrailId,
        GUARDRAIL_ARN: existingGuardrailArn,
      },
    });

    // Grant Lambda permission to be invoked by ALB
    lambdaFunction.addPermission('AllowALB', {
      principal: new iam.ServicePrincipal('elasticloadbalancing.amazonaws.com'),
    });

    // Create Application Load Balancer
    const alb = new elbv2.ApplicationLoadBalancer(this, 'BedrockALB', {
      vpc,
      internetFacing: true,
    });

    // Create target group for Lambda (Lambda targets don't require VPC)
    const lambdaTargetGroup = new elbv2.ApplicationTargetGroup(this, 'LambdaTargetGroup', {
      targets: [new targets.LambdaTarget(lambdaFunction)],
      targetType: elbv2.TargetType.LAMBDA,
    });

    // Create listener for ALB
    const listener = alb.addListener('Listener', {
      port: 80,
      defaultTargetGroups: [lambdaTargetGroup],
    });

    // Output ALB DNS name with export name for cross-stack references
    new cdk.CfnOutput(this, 'ALBDnsName', {
      value: alb.loadBalancerDnsName,
      description: 'DNS name of the Application Load Balancer',
      exportName: `${this.stackName}-ALBDnsName`,
    });

    // Output Guardrail ARN
    new cdk.CfnOutput(this, 'GuardrailArn', {
      value: existingGuardrailArn,
      description: 'ARN of the existing Guardrail',
      exportName: `${this.stackName}-GuardrailArn`,
    });

    new cdk.CfnOutput(this, 'GuardrailId', {
      value: existingGuardrailId,
      description: 'ID of the existing Guardrail',
      exportName: `${this.stackName}-GuardrailId`,
    });
  }
}
