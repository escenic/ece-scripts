#!/bin/bash -e

echo "--- START : post install hook - install ece install ---"

# add archive key for apt.escenic.com
curl -s http://apt.escenic.com/archive.key | ssh -F $2/ssh.conf guest 'sudo apt-key add -'

# add repo to sources list
echo "deb http://apt.escenic.com unstable main" | ssh -F $2/ssh.conf guest 'sudo tee > /dev/null /etc/apt/sources.list.d/vizrt.list'

# install escenic scripts
ssh -F $2/ssh.conf guest 'sudo apt-get update && sudo apt-get -y install escenic-content-engine-installer'
ssh -F $2/ssh.conf guest 'sudo apt-get update && sudo apt-get -y install escenic-content-engine-scripts'

echo "--- END : post install hook - install ece install ---"
