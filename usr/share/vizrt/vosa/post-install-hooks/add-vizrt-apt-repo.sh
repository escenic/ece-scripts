#! /usr/bin/env bash

## Adds the Vizrt APT repository
echo deb http://apt.escenic.com unstable main | \
  ssh -F $2/ssh.conf guest sudo tee /etc/apt/sources.list.d/apt.escenic.com.list \
  > /dev/null

curl -s http://apt.escenic.com/archive.key | \
  ssh -F $2/ssh.conf guest sudo apt-key add - \
  > /dev/null

ssh -F $2/ssh.conf guest sudo apt-get -qq update
