from centos:latest

maintainer CCI & Escenic <support@escenic.com>

arg ECE_APT_USER
arg ECE_APT_PASSWORD

run echo $' \n\
credentials: \n\
  - site: maven.escenic.com \n\
    user: '${ECE_APT_USER}$' \n\
    password: '${ECE_APT_PASSWORD}$' \n\
  - site: yum.escenic.com \n\
    user: '${ECE_APT_USER}$' \n\
    password: '${ECE_APT_PASSWORD}$' \n\
\n\
environment: \n\
  java_oracle_licence_accepted: true \n\
\n\
' > /etc/ece-install.yaml

# Official Escenic & CUE releases
run echo $' \n\
[escenic] \n\
name=Escenic packages \n\
gpgcheck=0 \n\
baseurl=https://'${ECE_APT_USER}':'${ECE_APT_PASSWORD}'@yum.escenic.com/rpm/ \
' > /etc/yum.repos.d/escenic.repo

# Install the installer
run yum install -y \
        escenic-common-scripts \
        escenic-content-engine-installer
