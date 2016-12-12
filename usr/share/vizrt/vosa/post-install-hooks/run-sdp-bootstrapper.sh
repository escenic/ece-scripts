#!/bin/bash -e

# arguments $1 -- /etc/vizrt/vosa/available.d/imagename
# arguments $2 -- /var/lib/vizrt/vosa/images/imagename

# mandatory sdp.conf parameter
#  REALM=development

# optional sdp.conf parameter (default shown below)
SDP_BOOTSTRAPPER=

# if SDP_BOOTSTRAPPER is set to anything, it is assumed to be the URL
# from which to download a source tar.gz file.
#  ENVIRONMENT corresponds to sdp-bootstrap-instance --environment
#  CLUSTER     corresponds to sdp-bootstrap-instance --cluster
#  MACHINE     corresponds to sdp-bootstrap-instance --machine


conf=$1
data=$2
# This hook Expects sdp.xml to be present in $conf/

# Seed the image with sdp.xml
source $1/sdp.conf


if [ -z "$REALM" ] ; then
  echo "realm is not set in $1/sdp.conf. It should be development or production."
  exit 1
fi

guest="ssh -F $2/ssh.conf root@guest"

if $guest [ -d /etc/apt/sources.list.d ] ; then
  $guest tee /etc/apt/sources.list.d/vizrt.list <<EOF
deb http://apt.vizrt.com/ akita main non-free
EOF

  $guest tee /etc/apt/preferences.d/30prefer-vizrt-akita-packages <<EOF
Package: *
Pin-Priority: 600
Pin: release a=unstable
EOF
 $guest tee /etc/apt/preferences.d/40ubuntu-unzip-package <<EOF
Package: unzip
Pin-Priority: 600
Pin: release v=12.04,o=Ubuntu,a=precise,n=precise,l=Ubuntu,c=main
EOF

  $guest apt-key add - <<EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (GNU/Linux)

mQENBFB33KEBCACrGwM6J1aCgSfGZvHuxFJ6a4LebpzgSrg+jAQDXSiyWp7aBDpX
80TCEFWPl5Wps9ARXdF2ciFdYfpmcA9wxErmyLemQ9c+2oKfsGAb0R4b0tRLCL3k
vK7cf4z2+2CD37ptOSFLlKz5cTAOv4gJIzbL/XDwCxWw720LMz8vzfq4+MtfesZ4
zTiq5tkA6UxTBWv/eUpLc1we+0P1I5Bm6Q0STydNNul7UuKvoArTfEkS8kV82qVA
WGF5IH0EukeVZOoojyq5xoiNQyX1pRhfzWmfv9gPr0wXD9drSnTAUIhPVwdNqKeC
Gb6HChp4cszpCDnd+QqdvegL4nmUBjeyxqALABEBAAG0J1ZpenJ0IE9ubGluZSA8
c3VwcG9ydC5vbmxpbmVAdml6cnQuY29tPokBOAQTAQIAIgUCUHfcoQIbAwYLCQgH
AwIGFQgCCQoLBBYCAwECHgECF4AACgkQaNLae4JnuP01+Qf8CFMDnVR26gqqJ7rJ
d5gc4SMhCVzVVh6qUB90VwJgRqQm3wHEyaJWDHIxxmysNZQCK9MZJ48MkO6jsvxH
9zNo7wM6NCaNdZs9OM6QlsLTjD/SxlMXbJ3cmi49jUvhV6W0T6cCCKCboSY5GMB/
ReUjR0B9emjphevctYgl+F7gYTEFGePI3stSuKi2XZ0/TSTJz+zCYonAfFWIOPVa
TS2o3tdJfysAzqfhlMNhlMPwhdwNzRFwW5M8q51Xw2xrKL6jEygtokusg9bV/eu+
F+PD2PzksFyH0WDXow+hNuUe8Z9wfveh0N3CWJiESrm6KSfkattBtFYSbR94rFgL
kahPF7kBDQRQd9yhAQgAsuga6GnvDlsK/fh7dv2zvwqWDN6z5yc2YRV8CY7dlGyR
Q+C0f3BQ6g8fOO7pARYEVPPDdLL3UPtLpFGnw4aljwb/6h2KBUWTfsnVLKb7N6v5
BWnUyuI23i0H5JtFGsskvPa4TCKmJBBvXwoBuwfxgyPy4QvRo+3XZCXabY1SQjhk
hwpJg06TA7+L/je5jNA5VPmMSjCMuIPyL9VEVCt0dK8eTVoojKjjxWnfM0LxxmJD
0jbzuuOiuuEG0P1yCLRZXu76J+eNua1kIz++n17Kg+kYRoYqWXMZUCZtWtjypyzK
GCKTYdf16BAlrvE+RkbRiKs7apl40Roml2tUIOMjYQARAQABiQEfBBgBAgAJBQJQ
d9yhAhsMAAoJEGjS2nuCZ7j9w9cH/R/9wMHy7OoRZsFUbiY2/AFJ9EH8j4akntfR
O1gA3GHy+ECiHAfjgZce5FjUKpWlDblDCSVHmy3bWQxmVEcVmq+XVIxxXfC1dHnu
zniOmUu+kNY747KxXxLd3Tn2Oez9XtTj1RVnLlRTLbIN3Q59e2o60RKG6SKG5fd2
cHcyyxMCLjQgcSqDgwV2UIoV0CaVrrKx6YWOV1mz13OFVA0UJ++5ZY7INMgJImvg
XeJVJ9CO0rBGbLjPqXw3UzGdGb862SgIOLBXKnoDYN9E4XIz2pMau/O5OqAMss6H
+Ta/zziJw0Den8GrZbIrxJ4zbGG0lapP2vZB44NMJF0qYQH84Yg=
=yGzl
-----END PGP PUBLIC KEY BLOCK-----
EOF


$guest apt-get update \
    -o Dir::Etc::sourcelist="sources.list.d/vizrt.list" \
    -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

$guest apt-get --yes install \
   escenic-common-scripts \
   vosa-sdp-bootstrapper \
   xml2 \
   python-pip \
   haveged

fi



# Centos below this line

if $guest [ -d /etc/yum.repos.d ] ; then
  $guest tee /etc/yum.repos.d/vizrt.repo <<EOF
[Vizrt]
name=Vizrt packages
baseurl=http://yum.vizrt.com/rpm/
gpgcheck=0
EOF

   

  $guest rpm -ivh ftp://ftp.pbone.net/mirror/archive.fedoraproject.org/fedora/linux/updates/14/x86_64/xml2-0.5-1.fc14.x86_64.rpm

  $guest yum -y install \
   escenic-common-scripts \
   vosa-sdp-bootstrapper \
   python-pip \
   perl-JSON-XS \
   perl-YAML \
   haveged

  # Centos comes with an old version of distribute, needed for
  # installation of jsonpipe. Upgrading it.
  $guest easy_install -U distribute
  $guest pip install jsonpipe

fi

# Install pystache (mandatory for vosa-sdp-bootstrapper)
$guest pip install pystache

# experimental: remove the vosa-sdp-bootstrapper, then download a
# source package and use that instead.
if [ ! -z "${SDP_BOOTSTRAPPER}" ] ; then
  if $guest [ -d /etc/yum.repos.d ] ; then
    $guest yum -y remove vosa-sdp-bootstrapper
  else
    $guest apt-get -y remove vosa-sdp-bootstrapper
  fi
  tmpdir=$($guest mktemp -d)
  curl -s $SDP_BOOTSTRAPPER | $guest tar xz -C $tmpdir
  $guest cp -rp $tmpdir/*/usr /
fi

# ask the instance to bootstrap itself.
$guest sdp-bootstrap-instance \
   --state preparation \
   --verbose \
   --run-module baseline \
   --run-module restore-backup || exit $?

echo "System has been prepared."

if [ ! -r $conf/sdp.xml ] ; then
  echo "No sdp.xml file in $conf so I can't continue."
  exit 0 
fi

$guest tee /etc/sdp.xml < $1/sdp.xml > /dev/null


# copy private key from host to guest, if present
if [ -r $1/secret-gpg-key.asc ] ; then
  $guest gpg --import < $1/secret-gpg-key.asc
# TODO else create a new private key.
fi


$guest sdp-bootstrap-instance \
     --state activation \
     --sdp-file /etc/sdp.xml \
     ${ENVIRONMENT+--environment $ENVIRONMENT} \
     ${CLUSTER+--cluster $CLUSTER} \
     ${MACHINE+--machine $MACHINE} \
     --verbose
