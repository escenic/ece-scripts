# -*- mode: sh; sh-shell: bash; -*-
#
## Functions specific to RedHat and derivatives like CentOS
##
## author: torstein@escenic.com
##

## EPEL is a high quality repo for packages that we're dependent on,
## like jq.
rh_add_epel_repo() {
  if [ "${on_redhat_or_derivative-0}" -eq 0 ]; then
    return
  fi

  local major=7
  major=$(lsb_release -r |
            sed -n -r 's#Release:[^0-9]*([0-9]+)\..*#\1#p')
  local package_name=epel-release
  local url=https://dl.fedoraproject.org/pub/epel/${package_name}-latest-${major}.noarch.rpm

  if ! is_rpm_already_installed_by_name "${package_name}"; then
    run rpm -Uvh "${url}"
  fi
}
