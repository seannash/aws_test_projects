import * as cdk from 'aws-cdk-lib/core';
import * as lightsail from 'aws-cdk-lib/aws-lightsail';
import { Construct } from 'constructs';
import * as fs from 'fs';
import * as path from 'path';

export interface TorNodeStackProps extends cdk.StackProps {
  /**
   * Name of the SSH key pair to use for the Lightsail instance.
   * If not provided, defaults to 'tor-node-keypair'.
   * The key pair must be created in Lightsail before deploying this stack.
   * Use the create-keypair.sh script to create it.
   */
  readonly keyPairName?: string;
}

export class TorNodeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: TorNodeStackProps) {
    super(scope, id, props);

    const keyPairName = props?.keyPairName || 'tor-node-keypair';

    // Read the initialization script
    const initScriptPath = path.join(__dirname, '../scripts/instance-init.sh');
    let initScript = fs.readFileSync(initScriptPath, 'utf8');
    
    // Ensure script ends with newline (required for cloud-init)
    if (!initScript.endsWith('\n')) {
      initScript += '\n';
    }

    // Output the key pair name for reference
    new cdk.CfnOutput(this, 'KeyPairName', {
      value: keyPairName,
      description: 'Name of the SSH key pair for the Lightsail instance',
    });

    // Lightsail instance with:
    // - 512MB RAM
    // - 2 vCPU
    // - 20GB SSD
    // - 1 TB Transfer
    // - OS Only
    // - Debian 12.12
    const instance = new lightsail.CfnInstance(this, 'TorNodeInstance', {
      instanceName: 'tor-node-instance',
      blueprintId: 'debian_12', // OS Only Debian 12 (can be updated to 12.12 after instance creation)
      bundleId: 'nano_3_0', // Bundle ID for 512MB RAM, 2 vCPU, 20GB SSD, 1TB transfer
      keyPairName: keyPairName, // Attach the SSH key pair
      availabilityZone: props?.env?.region ? `${props.env.region}a` : undefined,
      // Initialization script that runs on first boot
      userData: initScript,
      // Configure firewall rules for Tor
      // Tor uses these ports:
      // - OR port (9013): For relay connections from other Tor nodes
      // - obfs4 port (9014): For obfuscated transport connections
      // - SSH port (22): Already open by default, but explicitly defined for clarity
      networking: {
        ports: [
          {
            accessDirection: 'inbound',
            accessFrom: '0.0.0.0/0',
            accessType: 'Public',
            protocol: 'tcp',
            fromPort: 22,
            toPort: 22,
          },
          {
            accessDirection: 'inbound',
            accessFrom: '0.0.0.0/0',
            accessType: 'Public',
            protocol: 'tcp',
            fromPort: 9013,
            toPort: 9013,
          }
        ],
      },
    });

    // Create static IP and attach it to the instance
    const staticIp = new lightsail.CfnStaticIp(this, 'TorNodeStaticIp', {
      staticIpName: 'tor-node-static-ip',
      attachedTo: instance.instanceName!,
    });
    staticIp.addDependency(instance); // Ensure instance is created before attaching static IP

    // Output instance information
    new cdk.CfnOutput(this, 'InstanceName', {
      value: instance.instanceName!,
      description: 'Name of the Lightsail instance',
    });

    // Output static IP information
    new cdk.CfnOutput(this, 'StaticIpName', {
      value: staticIp.staticIpName!,
      description: 'Name of the static IP address',
    });

    // Note: Static IP is attached to the instance
    // Use the get-instance-ip.sh script or AWS CLI to retrieve it:
    // aws lightsail get-instance --instance-name tor-node-instance --query 'instance.publicIpAddress' --output text
    new cdk.CfnOutput(this, 'GetInstanceIPCommand', {
      value: `aws lightsail get-instance --instance-name ${instance.instanceName} --query 'instance.publicIpAddress' --output text`,
      description: 'Command to get the instance public IP address (static IP)',
    });
  }
}
