#!/bin/bash
# Simple test script to verify userData execution

# Create a test file immediately
echo "UserData script executed at $(date)" > /tmp/userdata-test.txt
echo "Script location: $0" >> /tmp/userdata-test.txt
echo "User: $(whoami)" >> /tmp/userdata-test.txt

# Also log to cloud-init standard location
echo "UserData executed successfully" >> /var/log/userdata-test.log

# Create the instance-init log file
touch /var/log/instance-init.log
chmod 666 /var/log/instance-init.log

# Now run the actual initialization script
exec /var/lib/cloud/instance/scripts/part-001 2>&1 | tee -a /var/log/instance-init.log

