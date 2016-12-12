#!/bin/bash

# This is an helper script to make an ova file from the vmdk image created before using vosa.
# This script take three parameters configuration directory i.e. /etc/vizrt/vosa/available.d/instnace-name,
# image directory i.e. /var/lib/vizrt/vosa/images/instance-name and instance-name respectively.

#########################################
# Global variables are declared here.
config=$1
image=$2
instance=$3

#Reads the configuration file and parses user defined data.

if [ ! -e ${config}/ova.conf ]; then
  echo "There is no ${config}/ova.conf file. Exiting ...!"
  exit 2
else
source $(dirname $0)/functions
source $(dirname $0)/ova_config_parser
parse_config_file $config/ova.conf ova_config_
fi

vboxmanage_output_dir=${ova_config_output_directory}

#Creates ova file from previously generated vmdk file by vosa -i {instance} make command.
function make_ova_file() {
if [ ! -e "${vboxmanage_output_dir}/${instance}.vmdk" ] ; then
  echo "sparse image ${vboxmanage_output_dir}/${instance}.vmdk does not exist"
  echo "You should first make an vmdk file by running > vosa -i ${instance} make"
  exit 2
fi

#for this will only work with virtualbox version 4. Cause --synthcpu off option is removed from version 5.
options=$(cat <<EOF | grep ^[^#]
--name ${instance}
--ostype ${ova_config_ostype}
--memory ${ova_config_vm_memory}
# --pagefusion on|off
# --vram <vramsize in MB>
--acpi on
#--pciattach 03:04.0
#--pciattach 03:04.0@02:01.0
#--pcidetach 03:04.0
--ioapic on
--pae on
#--hpet on|off
#--hwvirtex on|off
#--hwvirtexexcl on|off
#--nestedpaging on|off
#--largepages on|off
#--vtxvpid on|off
--synthcpu off
#--cpuidset <leaf> <eax> <ebx> <ecx> <edx>
#--cpuidremove <leaf>
#--cpuidremoveall
#--hardwareuuid <uuid>
--cpus ${ova_config_cpus}
#--cpuhotplug on|off
#--plugcpu <id>
#--unplugcpu <id>
#--cpuexecutioncap <1-100>
#--rtcuseutc on|off
#--monitorcount <number>
#--accelerate3d on|off
#--accelerate2dvideo on|off
#--firmware bios|efi|efi32|efi64
#--chipset ich9|piix3
#--bioslogofadein on|off
#--bioslogofadeout on|off
#--bioslogodisplaytime <msec>
#--bioslogoimagepath <imagepath>
#--biosbootmenu disabled|menuonly|messageandmenu
#--biossystemtimeoffset <msec>
#--biospxedebug on|off
--boot1 dvd
--boot2 disk
--boot3 none
--boot4 none

# NIC 1, NAT, for outbound traffic
--nic1 nat
--nictype1 virtio
--cableconnected1 on
--macaddress1 auto

# NIC 2, Host Only, for inbound connections
--nic2 hostonly
--hostonlyadapter2 vboxnet0
--nictype2 virtio
--cableconnected2 on
--macaddress2 auto

--audio none
--clipboard disabled
--vrde off
--usb off
EOF
)
#First create environment
vboxmanage createvm --name ${instance} --basefolder /tmp/${instance} --ostype Ubuntu_64 --register

#Modified the environment
vboxmanage modifyvm ${instance} $options
#
vboxmanage storagectl ${instance} --name "IDE Controller" --add ide --controller PIIX4 --hostiocache on --bootable on

vboxmanage storageattach ${instance} \
                            --storagectl "IDE Controller" \
                            --port 0 \
                            --device 0 \
                            --type hdd \
                            --medium ${vboxmanage_output_dir}/${instance}.vmdk

rm -f ${vboxmanage_output_dir}/${instance}.ova
vboxmanage export ${instance} --output ${vboxmanage_output_dir}/${instance}-tmp.ova \
                            --vsys 0 \
                            --product "Escenic ${instance} Development Image" \
                            --vendor "${ova_config_vendor}" \
                            --vendorurl "${ova_config_vendorurl}" \
                            --eula "${ova_config_agreement}"
#Make a vagrant "box" too
rm -f ${vboxmanage_output_dir}/${instance}-box.ova
vboxmanage export ${instance} --output ${vboxmanage_output_dir}/${instance}-box.ova \
                            --vsys 0 \
                            --product "Escenic ${instance} Development Image" \
                            --vendor "${ova_config_vendor}" \
                            --vendorurl "${ova_config_vendorurl}" \

chmod +r ${vboxmanage_output_dir}/${instance}-tmp.ova
mv ${vboxmanage_output_dir}/${instance}-tmp.ova ${vboxmanage_output_dir}/${instance}.ova
chmod +r ${vboxmanage_output_dir}/${instance}-box.ova
(cd ${vboxmanage_output_dir}/; md5sum ${instance}.ova > ${instance}.ova.md5)
(cd ${vboxmanage_output_dir}/; md5sum ${instance}-box.ova > ${instance}-box.ova.md5)
vboxmanage unregistervm ${instance}

rm -rf /tmp/${instance}
}

#Creates encrypted ova file.
function make_encrypted_image() {
mkdir -p ${vboxmanage_output_dir}/$instance/
#This time we will move both vmdk and ova image to target directory
mv ${vboxmanage_output_dir}/$instance.* ${vboxmanage_output_dir}/$instance/
rm -f ${vboxmanage_output_dir}/$instance/$instance.ova.gpg
if [ -n "${ova_config_passphrase}" ]; then
  gpg --no-use-agent --batch --symmetric --passphrase "${ova_config_passphrase}"  ${vboxmanage_output_dir}/$instance/$instance.ova
  chmod +r ${vboxmanage_output_dir}/$instance/$instance.ova ${vboxmanage_output_dir}/$instance/$instance.ova.gpg
fi
}

#Execution sequence
make_ova_file
make_encrypted_image
