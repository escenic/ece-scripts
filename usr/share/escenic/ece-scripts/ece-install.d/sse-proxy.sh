# -*- mode: sh; sh-shell: bash; -*-

## ece-install module that installs and configures the SSE proxy and
## configures the web server to route its requests through the
## standard web port.
##
## by torstein@escenic.com

_sse_install_web_server() {
  install_packages_if_missing nginx
}

_sse_configure_nginx() {
  print_and_log "SSE proxy: configuring nginx to expose the SSE proxy ..."

  if [ "${on_debian_or_derivative}" -eq 1 ]; then
    local file=/etc/nginx/sites-available/sse-proxy
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    local file=/etc/nginx/default.d/sse-proxy
  else
    local file=/etc/nginx/nginx.conf.add
  fi

  log "SSE proxy: Writing nginx conf to ${file}"

  # We only support exposing the proxy through port 80 in the web
  # server.  fai_sse_proxy_exposed_port= is in this case, ignored (but
  # used elsewhere).
  cat > "${file}" <<EOF
server {
  server_name ${fai_sse_proxy_exposed_host-${HOSTNAME}};

  location / {
    proxy_pass http://${fai_sse_proxy_host-localhost}:${fai_sse_proxy_port-9080};
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_cache off;
    chunked_transfer_encoding off;

  }
}
EOF

  local target=
  target=/etc/nginx/sites-enabled/$(basename "${file}")
  if [ "${on_debian_or_derivative}" -eq 1 ] && [ ! -e "${target}" ]; then
    ln -s "${file}" "${target}"
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    # Don't need to do anything since we're not using
    # available/enabled
    :
  fi
}

_sse_configure_nursery() {
  print_and_log "SSE proxy: configuring Nursery ..."
  exposed_proxy_uri=http://${fai_sse_proxy_exposed_host-${HOSTNAME}}:${fai_sse_proxy_exposed_port-80}

  local file=/etc/escenic/engine/common/com/escenic/livecenter/Configuration.properties
  make_dir $(dirname "${file}")
  if [ -e "${file}" ]; then
    run sed -i "s#presentationSseProxyUri=.*#presentationSseProxyUri=${exposed_proxy_uri}#" "${file}"
  else
    cat > "${file}" <<EOF
presentationSseProxyUri=${exposed_proxy_uri}
EOF
  fi

  file=/etc/escenic/engine/webapp/webservice/com/escenic/webservice/resources/ChangelogFeed.properties
  make_dir $(dirname "${file}")
  if [ -e "${file}" ]; then
    run sed -i "s#sseEndpoint=.*#sseEndpoint=${exposed_proxy_uri}#" "${file}"
  else
    cat > "${file}" <<EOF
sseEndpoint=${exposed_proxy_uri}
EOF
  fi
}

_sse_configure_sse_proxy() {
  print_and_log "SSE proxy: configuring the proxy itself ..."
  local file=/etc/escenic/sse-proxy/sse-proxy.yaml
  cat > "${file}" <<EOF
server:
  applicationConnectors:
    - type: http
      port: ${fai_sse_proxy_port-9080}

  adminConnectors:
    - type : http
      port : ${fai_sse_proxy_admin_port-7090}

  gzip:
    enabled: false

backends:
EOF

  old_ifs=$IFS
  IFS=$'\n'
  for el in ${fai_sse_proxy_backends}; do
    IFS=' ' read -r uri user password <<< "${el}"
    cat >> "${file}" <<EOF
  - uri: ${uri}
    credentials:
      username: ${user}
      password: ${password}
EOF
  done
  IFS=$old_ifs


  cat >> "${file}" <<EOF
cors:
  allowedOrigins   : "*"
  allowedHeaders   : "X-Requested-With,Content-Type,Accept,Origin"
  allowedMethods   : "GET,POST,HEAD"
  preflightMaxAge  : "1800"
  allowCredentials : "true"
  exposedHeaders   : ""
  chainPreflight   : "true"

logging:
  level: INFO
  loggers:
    io.dropwizard: INFO
    com.escenic.sse.proxy: INFO
    com.escenic.common.broadcast.SynchronousBroadcaster: INFO
    com.escenic.sse.proxy.ProtectedHttpEndpoint: INFO
  appenders:
    - type: console
EOF
}

_sse_configure() {
  _sse_configure_nginx
  _sse_configure_nursery
  _sse_configure_sse_proxy
}

_sse_restart_services() {
  print_and_log "SSE proxy: Restarting all related services ..."
  /etc/init.d/sse-proxy stop &>> "${log}" || true
  run /etc/init.d/sse-proxy start

  # Works on Debian and  RedHat based systems.
  if [ "${on_debian_or_derivative}" -eq 1 ]; then
    run service nginx reload
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    run systemctl restart nginx
  else
    run /etc/init.d/nginx restart
  fi
}

install_sse_proxy() {
  print_and_log "Installing SSE proxy on ${HOSTNAME} ..."
  download_escenic_components
  _sse_install_web_server
  _sse_configure
  _sse_restart_services
}
