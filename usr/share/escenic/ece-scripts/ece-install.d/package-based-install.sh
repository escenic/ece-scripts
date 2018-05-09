# -*- mode: sh; sh-shell: bash; -*-

## Component handling package based installation of Escenic
## components. Code specific to install Escenic sofftware using APT,
## dpkg, YUM and or RPM goes here.
##
## author: torstein@escenic.com

## Since the updater package assumes a working ECE environment and we
## install it as a part of ece-install, it's a chicken and and egg
## problem. Therefore, we must here set up a few pre-requisites for
## the updater package to install smoothly.
_install_prerequisites_for_updater_package() {
  local the_tomcat_base=${appserver_parent_dir}/tomcat-${instance_name-engine1}
  set_ece_instance_conf java_home "${java_home}"
  set_ece_instance_conf tomcat_home "${appserver_parent_dir}/tomcat"
  set_ece_instance_conf tomcat_base "${the_tomcat_base}"

  make_dir "${the_tomcat_base}/webapps" \
           "${the_tomcat_base}/escenic/lib"
  run chown -R "${ece_user}:${ece_group}" "${the_tomcat_base}"
}

## Installs the configured escenic packages. If none were configured,
## just ECE will be installed.
install_configured_escenic_packages() {

  if [ "${on_debian_or_derivative}" -eq 1 ]; then
    if [ "${fai_package_deb_not_apt-0}" -eq 0 ]; then
      print_and_log "Will use APT for installing Escenic packages"
      _install_configured_escenic_packages_apt
    else
      print_and_log "Will use DEBs directly (not APT) for installing Escenic packages"
      _install_configured_escenic_packages_deb
    fi
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    print_and_log "Will use RPM for installing Escenic packages"
    _install_configured_escenic_packages_rpm
  fi
}

_install_configured_escenic_packages_apt() {
  local escenic_deb_packages=
  local package=
  for package in "${!fai_package_map[@]}"; do

    if [[ "${package}" =~ "escenic-content-engine-updater-"* ]]; then
      _install_prerequisites_for_updater_package
    fi

    local version=${fai_package_map[${package}]}
    if [ -n "${version}" ]; then
      escenic_deb_packages="${package}=${version} ${escenic_deb_packages}"
    else
      escenic_deb_packages="${package} ${escenic_deb_packages}"
    fi
  done

  install_packages_if_missing "${escenic_deb_packages-escenic-content-engine}"
}

_install_configured_escenic_packages_deb() {
  local package=
  for package in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${package}]}

    if [ -z "${version}" ]; then
      print_and_log "Must specify version of DEB ${package} when using DEBs instead of APT"
      remove_pid_and_exit_in_error
    fi

    local arch=all
    if [ -n "${fai_package_arch_map[${package}]}" ]; then
      arch=${fai_package_arch_map[${package}]}
    fi

    local deb_url=${fai_package_deb_base_url-http://apt.escenic.com}/pool/non-free/${package:0:1}/${package}/${package}_${version}_${arch}.deb
    local deb_file="${download_dir}/${deb_url##*/}"
    run wget \
        --http-user "${fai_package_apt_user}" \
        --http-password "${fai_package_apt_password}" \
        --continue \
        --quiet \
        --output-document "${deb_file}" \
        "${deb_url}"

    run dpkg -i "${deb_file}"
  done
}

_install_configured_escenic_packages_rpm() {
  local package=
  for package in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${package}]}

    if [ -z "${version}" ]; then
      print_and_log "You must specify version of RPM package ${package}"
      remove_pid_and_exit_in_error
    fi

    local arch=x86_64
    if [ -n "${fai_package_arch_map[${package}]}" ]; then
      arch=${fai_package_arch_map[${package}]}
    fi

    print "Downloading ${package}-${version}.${arch}.rpm ..."
    local rpm_url=${fai_package_rpm_base_url-http://yum.escenic.com/rpm}/${package}-${version}.${arch}.rpm
    local rpm_file="${download_dir}/${rpm_url##*/}"
    wget \
      --http-user "${fai_package_rpm_user}" \
      --http-password "${fai_package_rpm_password}" \
      --continue \
      --quiet \
      --output-document "${rpm_file}" \
      "${rpm_url}" &>> "${log}" || {

      log "Couldn't download ${package} using ${rpm_url}"
      # Since some packages, with various logic, have been moved to to
      # a cue sub directory (2017), we'll try again with 'cue'
      # appended to the base URL:
      local rpm_url=${fai_package_rpm_base_url-http://yum.escenic.com/rpm}/cue/${package}-${version}.${arch}.rpm
      local rpm_file="${download_dir}/${rpm_url##*/}"
      log "Trying to download ${package} using ${rpm_url} instead"
      run wget \
          --http-user "${fai_package_rpm_user}" \
          --http-password "${fai_package_rpm_password}" \
          --continue \
          --quiet \
          --output-document "${rpm_file}" \
          "${rpm_url}"
    }

    if ! is_rpm_already_installed "${rpm_file}"; then
      run rpm -Uvh "${rpm_file}"
    fi
  done
}

is_package_source_only_3rd_party() {
  [[ "${fai_package_only_3rd_party-0}" -eq 1 ]]
}

is_package_source_only_proprietary() {
  [[ "${fai_package_only_proprietary-0}" -eq 1 ]]
}

## Will return 0 if the package list is installable according to the
## mode ece-install runs in. The two modes available are: proriatary
## (only install CCI/Escenic software) and 3rdparty (only install free
## and open source software).
##
## If neither install mode has been selected, the method will return
## 0.
##
## $@ :: a list of package names
##
##  Will return 1 on empty list.
is_package_list_installable() {
  local package_list=$*

  if [ -z "${package_list}" ]; then
    return 1
  fi

  if is_package_source_only_proprietary; then
    for el in ${package_list}; do
      if [[ "${el}" == escenic* ||
              "${el}" == vosa* ||
              "${el}" == spore ||
              "${el}" == cue* ]]; then
        continue
      else
        log "$(basename "$0") runs in proprietary install mode only," \
            "so it'll not install 3rd party package=${el}"
        return 1
      fi
    done
  elif is_package_source_only_3rd_party; then
    for el in ${package_list}; do
      if [[ "${el}" == escenic* ||
              "${el}" == vosa* ||
              "${el}" == spore ||
              "${el}" == cue* ]]; then
        log "$(basename "$0") runs in 3rd party install mode only," \
            "so it'll not install proprietary package=${el}"
        return 1
      else
        continue
      fi
    done
  fi
}
