#!/bin/bash -e

echo "--- START : post install hook - add vizrt repo ---"

# add archive key for apt.escenic.com
curl -s http://apt.escenic.com/archive.key | ssh -F $2/ssh.conf guest 'sudo apt-key add -'

# add repo to sources list
echo "deb http://apt.escenic.com unstable main" | ssh -F $2/ssh.conf guest 'sudo tee > /dev/null /etc/apt/sources.list.d/escenic.list'

# update package lists
ssh -F $2/ssh.conf guest 'sudo apt-get update'

echo "--- END : post install hook - add vizrt repo ---"
