# -*- mode: sh; sh-shell: bash; -*-

## Security related features

## author: torstein@escenic.com

security_configure_selinux() {
  if [ "${fai_security_configure_selinux-1}" -eq 0 ]; then
    return
  fi

  command -v setsebool &> /dev/null || {
    log "setsebool not available, will not configure SELinux"
  }

  # Give SELinux access to httpd (nginx in our case) to use the
  # network
  setsebool -P httpd_can_network_connect 1
}

## Configures firewalld according to the ece-install profile(s)
## active.
security_configure_firewalld() {
  if [ "${fai_security_configure_firewall-1}" -eq 0 ]; then
    return
  fi

  command -v firewall-cmd &> /dev/null || {
    log "firewall-cmd not available, will not configure firewall"
    return
  }

  local zone=
  zone=$(firewall-cmd --get-active-zones | head -n 1)

  # Add second interface to the firewall rules and enable 80 and 8080
  # routing
  local secondary_interface zone
  for secondary_interface in $(get_secondary_interfaces); do
    run firewall-cmd \
        --permanent \
        --zone="${zone}" \
        --add-interface "${secondary_interface}"
  done

  if _security_should_open_http_and_https; then
    run firewall-cmd --permanent --zone="${zone}" --add-port=80/tcp
    run firewall-cmd --permanent --zone="${zone}" --add-port=443/tcp
  fi

  if [[ "${fai_environment-production}" != prodution ]]; then
    local ports="
      ${fai_analysis_db_port}
      ${fai_analysis_port}
      ${fai_cache_port}
      ${fai_db_port}
      ${fai_editor_port}
      ${fai_presentation_port}
      ${fai_search_port}
      ${fai_sse_proxy_ece_port}
      ${fai_sse_proxy_exposed_port}
    "
    local port_to_open=
    for port_to_open in ${ports}; do
      run firewall-cmd \
          --permanent \
          --zone="${zone}" \
          --add-port="${port_to_open}"/tcp
    done
  fi

  run firewall-cmd --reload
}

_security_should_open_http_and_https() {
  [[ "${fai_cache_install-0}" -eq 1 ||
       "${fai_sse_proxy_install-0}" -eq 1 ||
       "${fai_cue_install-0}" -eq 1 ]]
}
