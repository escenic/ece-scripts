default_java_version=1.6
sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/6u39-b04/jdk-6u39-linux-i586.bin
if [[ $(uname -m) == "x86_64" ]]; then
  sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm
fi
  
# Install oracle java from webupd8
# http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html
function install_oracle_java(){
  # First get the java version
  server_java_version=${fai_server_java_version-${default_java_version}}
  debian_package_name=""

  if [ $server_java_version = "1.6" ]; then
    debian_package_name="oracle-java6-installer"
    java_home="/usr/lib/jvm/java-6-oracle"
  elif [ $server_java_version = "1.7" ]; then
    debian_package_name="oracle-java7-installer"
    java_home="/usr/lib/jvm/java-7-oracle"
  #elif [ $server_java_version = "1.8" ]; then
  #  debian_package_name="oracle-java8-installer"
  #  java_home="/usr/lib/jvm/java-8-oracle"
  else
    # Error: Invalid java version
    print_and_log "Unsupported Java version. Cannot proceed. Exiting ...."
    return 0
  fi

  install_packages_if_missing python-software-properties software-properties-common
  run add-apt-repository -y ppa:webupd8team/java
  run apt-get update
  echo "$debian_package_name shared/accepted-oracle-license-v1-1 boolean true" | debconf-set-selections
  install_packages_if_missing $debian_package_name
}

## Returns 0 if Oracle Java is installed, 1 if it's not (in PATH).
function _java_is_sun_java_already_installed() {
  if [ -e "${java_home}/bin/java" ]; then
    "${java_home}/bin/java" -version 2>&1 | grep -q -w HotSpot
  elif [ -x /usr/bin/java ]; then
    /usr/bin/java -version -version 2>&1 | grep -q -w HotSpot
  else
    return 1
  fi
}

## $1 :: dir of the JDK
function _java_update_java_env_from_jdk_dir() {
  local dir=$1
  update-alternatives --set java "${dir}/jre/bin/java"
  for cmd in javac jar javap javah jstat; do
    update-alternatives --set "${cmd}" "${dir}/bin/${cmd}"
  done

  export java_home=${dir}
}

function _java_update_java_env_from_jdk_rpm() {
  local rpm=$1
  local rpm_java_home=
  rpm_java_home=$(
    rpm -qlp "${rpm}" |
      grep bin/javac |
      sed 's#/bin/javac##')

  _java_update_java_env_from_jdk_dir "${rpm_java_home}"
}

function _java_update_java_env_from_java_bin() {
  local java_bin=
  java_bin=$(which java)
  local real_java_bin=

  # the alternatives system is only two link deep:
  #
  # /usr/bin/java -> /etc/alternatives/java -> /actual/bin/java
  if [ -h "${java_bin}" ]; then
    java_bin=$(readlink "${java_bin}")
    if [ -h "${java_bin}" ]; then
      java_bin=$(readlink "${java_bin}")
    fi
  fi

  real_java_bin=${java_bin}

  local jdk_dir=${real_java_bin%/*}
  # Remove jre/bin
  jdk_dir=${jdk_dir//\/jre\/bin}
  # If this wasn't a <jdk>/jre/bin/java reference, it's probably
  # <jdk?>/bin/java, hence remove the bin again.
  jdk_dir=${jdk_dir//\/bin}

  _java_update_java_env_from_jdk_dir "${jdk_dir}"
}

function install_sun_java_on_redhat() {
  if _java_is_sun_java_already_installed; then
    print_and_log "Sun Java is already installed on $HOSTNAME"
    _java_update_java_env_from_java_bin
    return
  fi
  
  print_and_log "Downloading Oracle Java from download.oracle.com ..."
  local file_name=${download_dir}/${sun_java_bin_url##*/}
  run wget \
      --no-cookies \
      --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com ; oraclelicense=accept-securebackup-cookie" \
      -O $file_name \
      $wget_opts \
      $sun_java_bin_url

  if ! is_rpm_already_installed "${file_name}"; then
    run rpm -Uvh "${file_name}"
  fi

  _java_update_java_env_from_jdk_rpm "${file_name}"

  local version=$(java -version 2>&1 | grep version | cut -d'"' -f2)
  print_and_log "Oracle Java $version is now installed"

  add_next_step "By using Oracle Java, you must accept this license: " \
    "http://www.oracle.com/technetwork/java/javase/terms/license/"
}



