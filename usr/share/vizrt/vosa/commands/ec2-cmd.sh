#!/bin/bash

# Boots an amazon instance.

# Expects three arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where statefiles can be stored, followed by the ec2 command
# that should be executed, and any additional arguments.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

cmd=$3

if [ -z "$cmd" ] ; then
  echo "Three parameters are required, of which the third one is the"
  echo "name of the ec2-prefixed command to run, minus the ec2-prefix"
  echo "for example 'run-instances' or 'describe-instances'."
  exit 3
fi

if $USE_AWS_CLI ; then
  if [ -z "$EC2_BINARY" ] ; then
    EC2_BINARY=$(which 2>/dev/null aws)
  fi

  if [ -z "$EC2_BINARY" -o ! -x "$EC2_BINARY" ] ; then
    echo "Unable to figure out where aws is installed."
    echo "export EC2_BINARY to make it work."
    exit 2
  fi
else
  if [ -z "$EC2_BINARY" ] ; then
    EC2_BINARY=$(which 2>/dev/null ec2-$cmd)
  fi

  if [ -z "$EC2_BINARY" -o ! -x "$EC2_BINARY" ] ; then
    echo "Unable to figure out where ec2-$cmd is installed."
    echo "export EC2_BINARY to make it work."
    exit 2
  fi
fi

debug=3

function decho() {
  if [ $debug -ge $1 ] ; then
    echo "${@:2}"
  fi
}

function exitonerror() {
  rc=$1
  if [ "$rc" != "0" ] ; then
    echo "$2 (rc=$rc)"
    exit $rc
  fi
}


config=$1
image=$2

if [ -z "$image" -o -z "$config" ] ; then
  echo "You need to specify a config directory (e.g. /etc/vizrt/vosa/enabled.d/foo) "
  echo "and a place to hold the installation (e.g. /usr/lib/vizrt/vosa/images/foo)"
  echo "the former MUST exist and contain vosa configuration files"
  echo "the latter MUST also exist, and contain amazon.initialstate etc"
  exit 1
fi

# basic error checking
if [ ! -d "$config" ] ; then
  echo "Config directory $config isn't a directory."
  exit 1
fi

if [ ! -d "$image" ] ; then
  echo "image directory $image does not exist.  Can't continue."
  exit 1
fi

# todo: verify that basename and image don't end with slashes...

if [ "$(basename "$image")" != "$(basename "$config")" ] ; then
  echo "$image and $config appear to try to name different VMs. Try using $(basename $config) instead."
  exit 2
fi


have_read_amazon_config=0
function read_amazon_config() {
  [[ $have_read_amazon_config -eq 1 ]] && return
  source $(dirname $0)/functions
  source $(dirname $0)/amazon_config_parser
  # Parse all amazon config items
  parse_config_file $1 amazon_config_

  unset AWS_COMMON_OPTIONS
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --private-key $amazon_config_key "
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --cert $amazon_config_certificate "
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --region $amazon_config_region "
  have_read_amazon_config=1
}

# Example output from AWS CLI
cat > /dev/null <<EOF
390962791497   r-2db4d467
RESPONSEMETADATA       168ad1ba-8a7a-4419-9c1a-7f85d2d5a466
default        sg-65258a12
None   aki-75665e01    False   2013-07-15T08:16:27.000Z        None    i-04e0e849
MONITORING     disabled
STATE  0       pending
default        sg-65258a12
PLACEMENT      default None    eu-west-1a
STATEREASON    pending pending
EOF

# Example output from AWS CLI when booting into a VPC
cat > /dev/null <<EOF
866410366134	r-c3284b89
RESPONSEMETADATA	00ee4d6c-cf38-4ab4-ad4e-32caec6d5659
None	aki-71665e05	False	2013-07-15T12:13:52.000Z	172.31.34.128	vpc-011dbf6a	None	i-2c1d1661	ami-57b0a223	ip-172-31-34-128.eu-west-1.compute.internal	builder-root	None	subnet-061dbf6d	m1.medium	True	xen	x86_64	paravirtual	instance-store	0
MONITORING	disabled
STATE	0	pending
default	sg-923dd0fd
in-use	True	vpc-011dbf6a	None	eni-cfeb46a4	ip-172-31-34-128.eu-west-1.compute.internal	subnet-061dbf6d	866410366134	172.31.34.128
ip-172-31-34-128.eu-west-1.compute.internal	True	172.31.34.128
ATTACHMENT	attaching	0	True	eni-attach-6355ac0b	2013-07-15T12:13:52.000Z
default	sg-923dd0fd
PLACEMENT	default	None	eu-west-1b
STATEREASON	pending	pending
EOF

function get_aws_instance() {
  bootstatefile=$image/amazon.initialstate
  if [ -r $bootstatefile ] ; then
    aws_instance=$(awk < "$bootstatefile" -F '\t' '/^INSTANCE/ { print $8 }')
  fi
  if [ -z "$aws_instance" ] && [ -r $bootstatefile ] ; then
    # Hope that the 6th field continues to provide "i-"...
    aws_instance=$(cut < "$bootstatefile" -f 6 | grep 'i-')
  fi
  if [ -z "$aws_instance" ] && [ -r $bootstatefile ] ; then
    # Hope that the 6th field continues to provide "i-"...
    aws_instance=$(cut < "$bootstatefile" -f 8 | grep 'i-')
  fi
}


function invoke_ec2() {

  decho 1 "Invoking $EC2_BINARY"
  local cmdline=(
  $EC2_BINARY
  $AWS_COMMON_OPTIONS
  "${@}"
  )
  rc=1
  echo "Command to run on ec2:"
  echo "${cmdline[@]}"
  echo "# date $(date --iso)" >> /var/log/vosa-$(basename "$image")-ec2.log
  echo "${cmdline[@]}" >> /var/log/vosa-$(basename "$image")-ec2.log
  laststate="$("${cmdline[@]}" 2>> /var/log/vosa-$(basename "$image")-ec2.log)" 
  rc=$?
  echo "# return code $rc, $(echo -n "$laststate" | wc -c) bytes output" >> /var/log/vosa-$(basename "$image")-ec2.log
  echo "${laststate}" | tee $image/amazon.laststate
  if [ $cmd == "run-instances" -a ! -e $bootstatefile ] ; then
    cp $image/amazon.laststate $bootstatefile
  fi
  if [ $rc != 0 ] ; then
    exitonerror $rc "$EC2_BINARY returned with error."
  fi
}


if $USE_AWS_CLI ; then
  AWS_COMMON_OPTIONS="--output text ec2 $cmd"
else
  # Assume that the AWS_ACCESS_KEY and SECRET_KEY and REGION are set...
  read_amazon_config $1/amazon.conf
fi
get_aws_instance
shift
shift
shift
invoke_ec2 "${@/INSTANCE/$aws_instance}"

