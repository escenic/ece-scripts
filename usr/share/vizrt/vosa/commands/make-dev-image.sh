#!/bin/bash

# This is an helper script to make and vmdk image from the installed machine.
# It will make a copy of the vm and the do changes there to make it portable to vmdk.
# This script take three parameters configuration directory i.e. /etc/vizrt/vosa/available.d/instnace-name,
# image directory i.e. /var/lib/vizrt/vosa/images/instance-name and instance-name respectively.

#########################################
#Global variables declared here.
config=$1
image=$2
instance=$3

#Reads the ova.conf file and parse it get user defined values.
if [ ! -e ${config}/ova.conf ]; then
  echo "There is no ${config}/ova.conf file. Exiting ...!"
  exit 2
else
source $(dirname $0)/functions
source $(dirname $0)/ova_config_parser
parse_config_file $config/ova.conf ova_config_
fi

vboxmanage_output_dir=${ova_config_output_directory}

function run_on_dev_host() {
local command=$1
ssh -F ${image}/ssh.conf guest $command
}

#This function cleans up unnecessary packages and cached files to make the image size smaller.
function clean_up_image() {
echo "Cleaning up the dev image $instance"
run_on_dev_host "sudo apt-get --yes remove munin-node munin icinga"
# VirtualBox guest additions...
run_on_dev_host "sudo apt-get --yes install --no-install-recommends virtualbox-guest-utils virtualbox-guest-dkms"
run_on_dev_host "sudo rm -rf /tmp/ece-downloads"
run_on_dev_host "sudo rm -rf /opt/escenic"
run_on_dev_host "sudo rm -rf /var/cache/escenic/ece-install/*"
run_on_dev_host "sudo rm -f /var/cache/escenic/\*.ear"
run_on_dev_host "sudo sed -i -e "/system-info.*escenic/d" /etc/crontab"
run_on_dev_host "sudo locale-gen en_US.UTF-8"

# workaround to fix ece to start on boot if not so configured by ece-install
run_on_dev_host "[ -r /etc/init.d/ece ] &&"
run_on_dev_host "sudo update-rc.d ece defaults 80"
}

# This function shutdown the vm in a graceful manner.
function shutdown_guest_machine() {
run_on_dev_host "sudo shutdown -h now"
sleep 5;
echo "Waiting for machine to stop"
while [ 1 ] ; do
  dead=$(vosa -i ${instance} status | awk '{print $4}')
  [ "$dead" == "dead" ] && break;
  sleep 2;
  echo -n .
done
echo stopped.
vosa -i ${instance} status
vosa -i ${instance} stop
vosa -i ${instance} status
}

#This function does change root operation on the copied disk image of the vm.
function make_changes_to_disk() {
cp --sparse=always ${image}/disk.img ${image}/small.img
if [ -d ${image}/small ]; then
  rm -rf ${image}/small
fi
mkdir ${image}/small
mount -o loop ${image}/small.img ${image}/small
chroot ${image}/small <<END_OF_CHROOT
rm /etc/udev/rules.d/70-persistent-net.rules
sed -i '/^iface eth0/ s/static/dhcp/p; /^iface eth0/,/^[a-z]/d' /etc/network/interfaces
(echo; echo '# eth1 is a host-only network'; echo 'auto eth1'; echo 'iface eth1 inet dhcp') | tee > /dev/null -a /etc/network/interfaces
(echo; echo "# added to make local hostname resolvable anywhere"; echo "127.0.1.1 ${instance}") | tee > /dev/null -a /etc/hosts
(echo; echo "enable_remote_debugging=1";
 echo "enable_remote_monitoring=1") | tee -a > /dev/null /etc/escenic/ece-engine1.conf

# Resize heaps. 128/256 and 256/512.
sed -i s/min_heap_size=.*// /etc/escenic/ece-*.conf
sed -i s/max_heap_size=.*// /etc/escenic/ece-*.conf
echo min_heap_size=${ova_config_engine_min_heap}m | tee -a > /dev/null /etc/escenic/ece-engine1.conf
echo max_heap_size=${ova_config_engine_max_heap}m | tee -a > /dev/null /etc/escenic/ece-engine1.conf
echo min_heap_size=${ova_config_search_min_heap}m | tee -a > /dev/null /etc/escenic/ece-search1.conf
echo max_heap_size=${ova_config_search_max_heap}m | tee -a > /dev/null /etc/escenic/ece-search1.conf

# remove superflous jvm configuration, to make sure the instances can boot.
echo jvm_gc_settings= | tee -a > /dev/null /etc/escenic/ece-engine1.conf
echo jvm_gc_settings= | tee -a > /dev/null /etc/escenic/ece-search1.conf
echo jvm_gc_settings= | tee -a > /dev/null /etc/escenic/ece-analysis1.conf
# Make tomcat boot a lot faster!!
sed -i -e "/org.apache.catalina.startup.ContextConfig.jarsToSkip=/ s/=.*/=*.jar/" /opt/tomcat-*/conf/catalina.properties

# disable analysis instance on boot.
sed -i s/analysis_instance_list=.*/analysis_instance_list=/ /etc/default/ece


# Make a "top" user to show top on tty1 by writing "top"
useradd -d /nonexistent -M --no-user-group --system --shell /usr/local/bin/escenic-top ${ova_config_top_user}
passwd --delete ${ova_config_top_user}

rm -rf /var/lib/puppet/
apt-get -y remove puppet ruby x11-common

# apt-get remove cloud-init
# mkdir -p /usr/lib/cloud-init/
# (echo '#!/bin/sh'; echo 'exec /sbin/init "$@";') |
# tee /usr/lib/cloud-init/uncloud-init
# chmod +x /usr/lib/cloud-init/uncloud-init
apt-get --yes autoremove
apt-get clean
apt-get autoclean
rm -f /var/cache/apt/{pkg,srcpkg}cache.bin /var/cache/debconf/*
sed -i /final-message/d /etc/cloud/cloud.cfg
sync
END_OF_CHROOT
}

function install_extlinux() {
mkdir ${image}/small/extlinux/
extlinux --install ${image}/small/extlinux/
(
cat <<EOF
DEFAULT /vmlinuz
APPEND root=/dev/sda noapic init=/usr/lib/cloud-init/uncloud-init ubuntu-pass=${ova_config_vm_ubuntu_pass} ds=nocloud consoleblank=0
EOF
) |
tee ${image}/small/extlinux/extlinux.conf
umount ${image}/small
}

#This function is responsible for creating the vmdk image for the instance.
function make_vmdk_from_image() {
if [ ! -d $vboxmanage_output_dir ]; then
   mkdir -p $vboxmanage_output_dir
fi

if [ -e $vboxmanage_output_dir/${instance}.vmdk ]; then
  rm -f $vboxmanage_output_dir/${instance}.vmdk
fi
size=$(ls -l ${image}/small.img | awk '{print $5}')
local pv_options="-s $size -i 5 -e -t -r"
zerofree ${image}/small.img
cat ${image}/small.img | pv $pv_options | vboxmanage convertfromraw stdin $vboxmanage_output_dir/${instance}.vmdk $size --format VMDK
}

#checks dependencies of this script.
function check_dependencies() {
local missing=
for d in vboxmanage pv zerofree extlinux; do
  if ! which $d > /dev/null ; then
    missing="$d $missing"
  fi
done
if [ -n "$missing" ] ; then
  echo "Required packages '${missing}' missing. Please install it by apt-get install ${missing}. Exiting ..."
  exit 2
fi
}

function check_status_of_machine() {
local status=$(vosa -i ${instance} status | awk '{print $4}')
if [ -z "${status}" ] || [ "${status}" == "dead" ]; then
echo " The machine is not running please start the virtual machine."
echo "You can start and create ova file in a single command : vosa -i ${instance} start"
 exit 1
fi
}

function make_encrypted_image() {
mkdir -p ${vboxmanage_output_dir}/$instance/
cp  ${vboxmanage_output_dir}/$instance.* ${vboxmanage_output_dir}/$instance/
rm -f ${vboxmanage_output_dir}/$instance/$instance.vmdk.gpg
if [ -n "${ova_config_passphrase}"  ]; then
  gpg --no-use-agent --batch --symmetric --passphrase "${ova_config_passphrase}"  ${vboxmanage_output_dir}/$instance/$instance.vmdk
  chmod +r ${vboxmanage_output_dir}/$instance/$instance.vmdk ${vboxmanage_output_dir}/$instance/$instance.vmdk.gpg
fi
}

#Run sequence of this script.
check_dependencies
check_status_of_machine
clean_up_image
shutdown_guest_machine
make_changes_to_disk
install_extlinux
make_vmdk_from_image
make_encrypted_image
