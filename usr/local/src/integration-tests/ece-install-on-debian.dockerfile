from debian:latest

maintainer CCI & Escenic <support@escenic.com>

copy usr/ /usr/
copy etc/ /etc/

arg ECE_APT_USER
arg ECE_APT_PASSWORD

run echo " \n\
credentials: \n\
  - site: maven.escenic.com \n\
    user: ${ECE_APT_USER} \n\
    password: ${ECE_APT_PASSWORD} \n\
  - site: yum.escenic.com \n\
    user: ${ECE_APT_USER} \n\
    password: ${ECE_APT_PASSWORD} \n\
  - site: apt.escenic.com \n\
    user: ${ECE_APT_USER} \n\
    password: ${ECE_APT_PASSWORD} \n\
\n\
environment: \n\
  java_oracle_licence_accepted: true \n\
\n\
profiles: \n\
  editor: \n\
    install: yes \n\
\n\
packages: \n\
  - name: escenic-content-engine-6.7 \n\
" > /root/ece-install.yaml

# add contrib and non-free suites
run sed -r -i "s#stretch main#stretch main contrib non-free#" \
    /etc/apt/sources.list

run bash -x /usr/sbin/ece-install --only-3rd-party -f /root/ece-install.yaml
# run bash -x /usr/sbin/ece-install --only-proprietary -f /root/ece-install.yaml
