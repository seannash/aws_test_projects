import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ecr_assets from 'aws-cdk-lib/aws-ecr-assets';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as customresources from 'aws-cdk-lib/custom-resources';
import * as cr from 'aws-cdk-lib/custom-resources';

export class SimpleArchRdsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create VPC with public and private subnets
    const vpc = new ec2.Vpc(this, 'DatabaseVPC', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        {
          cidrMask: 24,
          name: 'isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
        },
      ],
    });

    // Create security group for RDS
    const dbSecurityGroup = new ec2.SecurityGroup(this, 'DatabaseSecurityGroup', {
      vpc,
      description: 'Security group for PostgreSQL database',
      allowAllOutbound: true,
    });

    // Create security group for ECS tasks
    const ecsSecurityGroup = new ec2.SecurityGroup(this, 'EcsSecurityGroup', {
      vpc,
      description: 'Security group for ECS tasks',
      allowAllOutbound: true,
    });

    // Allow ECS tasks to connect to the database
    dbSecurityGroup.addIngressRule(
      ecsSecurityGroup,
      ec2.Port.tcp(5432),
      'Allow PostgreSQL access from ECS tasks'
    );

    // Generate database credentials and store in Secrets Manager
    const dbCredentials = new rds.DatabaseSecret(this, 'DbCredentials', {
      username: 'dbadmin',
      excludeCharacters: '"@/\\',
    });

    // Create PostgreSQL database
    const database = new rds.DatabaseInstance(this, 'PostgresDatabase', {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.VER_15,
      }),
      vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
      securityGroups: [dbSecurityGroup],
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
      credentials: rds.Credentials.fromSecret(dbCredentials),
      databaseName: 'appdb',
      multiAz: false,
      allocatedStorage: 20,
      storageEncrypted: true,
      backupRetention: cdk.Duration.days(7),
      deleteAutomatedBackups: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For demo purposes
    });

    // Create ECS Cluster
    const cluster = new ecs.Cluster(this, 'MigrationCluster', {
      vpc,
      clusterName: 'flyway-migration-cluster',
    });

    // Create CloudWatch Log Group for Flyway
    const logGroup = new logs.LogGroup(this, 'FlywayLogGroup', {
      logGroupName: '/ecs/flyway-migration',
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Create IAM role for ECS task
    const taskRole = new iam.Role(this, 'FlywayTaskRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: 'Role for Flyway ECS task',
    });

    // Grant read access to the database secret
    dbCredentials.grantRead(taskRole);

    // Create execution role for ECS task
    const executionRole = new iam.Role(this, 'FlywayExecutionRole', {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonECSTaskExecutionRolePolicy'),
      ],
      description: 'Execution role for Flyway ECS task',
    });

    // Grant read access to secrets and logs
    dbCredentials.grantRead(executionRole);
    logGroup.grantWrite(executionRole);

    // Build Docker image with migrations
    const flywayImage = new ecr_assets.DockerImageAsset(this, 'FlywayImage', {
      directory: '.',
      file: 'Dockerfile',
    });

    // Create ECS Task Definition with Flyway
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'FlywayTaskDefinition', {
      taskRole,
      executionRole,
      cpu: 256,
      memoryLimitMiB: 512,
    });

    // Add Flyway container to task definition
    const container = taskDefinition.addContainer('FlywayContainer', {
      image: ecs.ContainerImage.fromDockerImageAsset(flywayImage),
      logging: ecs.LogDrivers.awsLogs({
        streamPrefix: 'flyway',
        logGroup,
      }),
      environment: {
        // Set JDBC URL using the database endpoint
        FLYWAY_URL: 'jdbc:postgresql://' + database.instanceEndpoint.hostname + ':5432/appdb',
      },
      secrets: {
        // Set database credentials from Secrets Manager
        FLYWAY_USER: ecs.Secret.fromSecretsManager(dbCredentials, 'username'),
        FLYWAY_PASSWORD: ecs.Secret.fromSecretsManager(dbCredentials, 'password'),
      },
      // Run the migrate command
      command: ['migrate'],
    });

    // Outputs
    new cdk.CfnOutput(this, 'DatabaseEndpoint', {
      value: database.instanceEndpoint.socketAddress,
      description: 'PostgreSQL database endpoint',
    });

    new cdk.CfnOutput(this, 'DatabaseSecretArn', {
      value: dbCredentials.secretArn,
      description: 'ARN of the database credentials secret',
    });

    new cdk.CfnOutput(this, 'ClusterName', {
      value: cluster.clusterName,
      description: 'ECS Cluster name',
    });

    new cdk.CfnOutput(this, 'TaskDefinitionArn', {
      value: taskDefinition.taskDefinitionArn,
      description: 'ARN of the ECS Task Definition',
    });

    // Get subnet IDs for the run-task command
    const privateSubnets = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    });

    // Create IAM role for Lambda to run ECS tasks
    const lambdaRole = new iam.Role(this, 'MigrationTriggerRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
      description: 'Role for Lambda function to trigger ECS migration task',
    });

    // Grant permissions to run ECS tasks on any revision of the task definition
    // Using wildcard allows the Lambda to run tasks even when the Docker image is updated
    const taskDefArnPattern = `arn:aws:ecs:${this.region}:${this.account}:task-definition/${taskDefinition.family}:*`;
    lambdaRole.addToPolicy(new iam.PolicyStatement({
      actions: ['ecs:RunTask'],
      resources: [taskDefArnPattern],
    }));

    // Grant permissions to describe and list ECS tasks
    lambdaRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'ecs:DescribeTasks',
        'ecs:ListTasks',
      ],
      resources: ['*'],
    }));

    lambdaRole.addToPolicy(new iam.PolicyStatement({
      actions: ['iam:PassRole'],
      resources: [taskRole.roleArn, executionRole.roleArn],
    }));

    lambdaRole.addToPolicy(new iam.PolicyStatement({
      actions: ['ec2:DescribeNetworkInterfaces'],
      resources: ['*'],
    }));

    // Create Lambda function to run the ECS task
    const runMigrationFunction = new lambda.Function(this, 'RunMigrationFunction', {
      runtime: lambda.Runtime.PYTHON_3_12,
      handler: 'run_migration.handler',
      role: lambdaRole,
      timeout: cdk.Duration.minutes(5),
      code: lambda.Code.fromAsset('lib/lambda'),
      environment: {
        CLUSTER_NAME: cluster.clusterName,
        TASK_DEFINITION: taskDefinition.family,
        SUBNETS: JSON.stringify(privateSubnets.subnetIds),
        SECURITY_GROUP_ID: ecsSecurityGroup.securityGroupId,
      },
    });

    // Create custom resource to trigger the Lambda on deployment
    const migrationTrigger = new cr.Provider(this, 'MigrationTrigger', {
      onEventHandler: runMigrationFunction,
    });

    new cdk.CustomResource(this, 'RunMigration', {
      serviceToken: migrationTrigger.serviceToken,
      properties: {
        Cluster: cluster.clusterName,
        TaskDefinition: taskDefinition.family,
        TaskDefinitionArn: taskDefinition.taskDefinitionArn, // Include ARN to trigger on Docker image changes
      },
    });

    new cdk.CfnOutput(this, 'RunMigrationCommand', {
      value: `aws ecs run-task --cluster ${cluster.clusterName} --task-definition ${taskDefinition.family} --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[${privateSubnets.subnetIds.join(',')}],securityGroups=[${ecsSecurityGroup.securityGroupId}],assignPublicIp=DISABLED}"`,
      description: 'Manual command to run database migration task (migrations run automatically on deploy)',
    });
  }
}
