# -*- mode: sh; sh-shell: bash; -*-

oracle_jdk_download_url=http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html

function _java_get_oracle_tarball_url() {
  if [ -n "${fai_java_download_url-""}" ]; then
    echo "${fai_java_download_url}"
    return
  fi

  curl -s  "${oracle_jdk_download_url}" |
    grep "$(uname -s) x64" |
    grep .tar.gz |
    grep -v demos |
    sort -r |
    head -n1 |
    sed -n -r  's#.*filepath":"(.*)", "MD5".*#\1#p'
}

function _java_get_oracle_rpm_url() {
  if [ -n "${fai_java_download_url-""}" ]; then
    echo "${fai_java_download_url}"
    return
  fi

  curl -s  "${oracle_jdk_download_url}" |
    grep "$(uname -s) x64" |
    grep .rpm |
    grep -v demos |
    sort -r |
    head -n1 |
    sed -n -r  's#.*filepath":"(.*)", "MD5".*#\1#p'
}

function install_oracle_java() {
  if _java_is_sun_java_already_installed; then
    print_and_log "Oracle Java is already installed on $HOSTNAME"
    _java_update_java_env_from_java_bin
    return
  fi

  if [ "${fai_java_oracle_licence_accepted-0}" -eq 0 ]; then
    print_and_log \
      "You must accept Oracle's licence:" \
      "http://www.oracle.com/technetwork/java/javase/terms/license/index.html" \
      "YAML conf: environment.java_oracle_licence_accpted = true" \
      "Conf: fai_java_oracle_licence_accepted=1"
    remove_pid_and_exit_in_error
  fi

  local sun_java_bin_url=
  sun_java_bin_url=$(_java_get_oracle_tarball_url)

  if [ "${on_debian_or_derivative-0}" -eq 1 ]; then
    _install_oracle_java_debian
  elif [ "${on_redhat_or_derivative-0}" -eq 1 ]; then
    _install_oracle_java_redhat
  fi
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

function _java_update_java_env_from_jdk_deb() {
  local deb=$1
  local deb_java_home=
  deb_java_home=$(
    dpkg -c "${deb}" |
      sed -n 's#/bin/javac##p' |
      sed 's#.*[.]##')

  _java_update_java_env_from_jdk_dir "${deb_java_home}"
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

## $1 :: uri
## $2 :: target file
function _download_oracle_file() {
  local uri=$1
  local target_file=$2

  print_and_log "Downloading Oracle Java from download.oracle.com ..."

  run wget \
      --no-cookies \
      --header 'Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com ; oraclelicense=accept-securebackup-cookie' \
      -O "${target_file}" \
      --inet4-only \
      --continue \
      "${uri}"
}

function _install_oracle_java_debian() {
  print_and_log "Creating a DEB package from the Oracle JDK tarball ..."
  sun_java_bin_url=${sun_java_bin_url//.rpm/.tar.gz}
  local file_name=${download_dir}/${sun_java_bin_url##*/}
  _download_oracle_file "${sun_java_bin_url}" "${file_name}"

  # dependencies for make-jpkg (which the package currently doesn't
  # define as such)
  install_packages_if_missing "
    build-essential
    fakeroot
    gcc
    java-common
    java-package
    libgtk2.0-0
  "

  # make-jpkg doesn't heed DEBIAN_FRONTEND=noninteractive. Also, old
  # versions (jessie) of make-jpkg insists on using fakeroot, so we
  # use ${ece_user} for this as this user has been created in
  # ece-install::common_pre_install
  run su - ${ece_user} -c "make-jpkg ${file_name} <<< Y"
  run mv $(getent passwd ${ece_user} | cut -d: -f6)/*${_java_version}*.deb \
      "${download_dir}/."
  run dpkg -i "${download_dir}/"*${_java_version}*.deb

  _java_update_java_env_from_jdk_deb "${download_dir}/"*${_java_version}*.deb
}

function _install_oracle_java_redhat() {
  print_and_log "Downloading & installing Oracle JDK RPM ..."

  local oracle_java_rpm_url=
  oracle_java_rpm_url=$(_java_get_oracle_rpm_url)

  local file_name=${download_dir}/${oracle_java_rpm_url##*/}
  _download_oracle_file "${oracle_java_rpm_url}" "${file_name}"

  if ! is_rpm_already_installed "${file_name}"; then
    run rpm -Uvh "${file_name}"
  fi

  _java_update_java_env_from_jdk_rpm "${file_name}"

  local version=
  version=$(java -version 2>&1 | grep version | cut -d'"' -f2)
  print_and_log "Oracle Java $version is now installed"

  add_next_step "By using Oracle Java, you must accept this license: " \
                "http://www.oracle.com/technetwork/java/javase/terms/license/"
}
