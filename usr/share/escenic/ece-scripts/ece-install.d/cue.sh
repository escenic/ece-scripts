# -*- mode: sh; sh-shell: bash; -*-

## ece-install module that installs and configures all CUE and CUE
## plugins defined in the configuration file. Furthermore, it sets up
## CORS and a web server.
##
## by torstein@escenic.com

default_cue_backend_ece=http://localhost:8080

_cue_setup_cors() {
  print_and_log "Configuring the CUE editor: CORS ..."
  _cue_setup_cors_nginx
}

_cue_setup_cors_nginx() {
  if [ "${on_debian_or_derivative-0}" -eq 1 ]; then
    _cue_setup_cors_nginx_debian
  elif [ "${on_redhat_or_derivative-0}" -eq 1 ]; then
    _cue_setup_cors_nginx_redhat
  fi
}

_cue_setup_cors_nginx_redhat() {
  local file=/etc/nginx/default.d/cue
  _cue_setup_cors_nginx_create_cors_setup_in_file "${file}"
}

_cue_setup_cors_get_allowed_origins() {
  local result=
  if [ -n "${fai_cue_cors_origins}" ]; then
    result=${fai_cue_cors_origins}
  else
    result=$(
      ifconfig |
        sed -r  -n 's#inet addr:([^ ]*) .*#\1#p' |
        grep -v 127.0.0.1
      )
    result="${HOSTNAME} ${result}"
  fi

  echo "${result}"
}

## $1 :; file
_cue_setup_cors_nginx_create_cors_setup_in_file() {
  local file=$1
  cat >> "${file}" <<EOF
server {
  location ~ "/(escenic|studio|webservice|webservice-extensions)/(.*)" {
EOF

  for origin in $(_cue_setup_cors_get_allowed_origins); do
    cat >> "${file}" <<EOF
    if (\$http_origin ~* (://${origin}(:[0-9]+)?)\$) {
      set \$cors "true";
    }
EOF
  done

  cat >> "${file}" <<EOF
    if (\$http_origin ~* (http://localhost(:[0-9]+)?)\$) {
      set \$cors "true";
    }
    if (\$request_method = 'OPTIONS') {
      set \$cors "\${cors}options";
    }
    if (\$request_method = 'GET') {
      set \$cors "\${cors}get";
    }
    if (\$request_method = 'HEAD') {
      set \$cors "\${cors}get";
    }
    if (\$request_method = 'POST') {
      set \$cors "\${cors}post";
    }
    if (\$request_method = 'PUT') {
      set \$cors "\${cors}post";
    }
    if (\$request_method = 'DELETE') {
      set \$cors "\${cors}post";
    }
    if (\$cors = "trueget") {
      add_header "Access-Control-Allow-Origin" "\$http_origin" always;
      add_header "Access-Control-Allow-Credentials" "true" always;
      add_header "Access-Control-Expose-Headers" "Link,X-ECE-Active-Connections,Location,ETag" always;
    }
    if (\$cors = "truepost") {
      add_header "Access-Control-Allow-Origin" "\$http_origin" always;
      add_header "Access-Control-Allow-Credentials" "true" always;
      add_header "Access-Control-Expose-Headers"
        "Link,X-ECE-Active-Connections,Location,ETag" always;
    }
    if (\$cors = "trueoptions") {
      add_header 'Access-Control-Allow-Origin' "\$http_origin";
      add_header 'Access-Control-Allow-Credentials' 'true';
      add_header 'Access-Control-Max-Age' 1728000;
      add_header 'Access-Control-Allow-Methods' 'GET, POST, HEAD, OPTIONS, PUT, DELETE';
      add_header 'Access-Control-Allow-Headers' 'Authorization,Content-Type,Accept,Origin,User-Agent,DNT,Cache-Control,X-Mx-ReqToken,Keep-Alive,X-Requested-With,If-Modified-Since,If-Match,If-None-Match,X-Escenic-Locks,X-Escenic-media-filename';
      add_header 'Content-Length' 0;
      add_header 'Content-Type' 'text/plain charset=UTF-8';
      return 204;
    }

    proxy_set_header Host \$http_host;
    proxy_pass ${fai_cue_backend_ece-${default_cue_backend_ece}};
  }
EOF
}

_cue_setup_cors_nginx_debian() {
  local file=/etc/nginx/sites-available/cue
  _cue_setup_cors_nginx_create_cors_setup_in_file "${file}"
  cat >> "${file}" <<EOF
  location ~ "/cue-web" {
    root /var/www/html;
  }
}
EOF

  local link_target=
  link_target="/etc/nginx/sites-enabled/$(basename "${file}")"
  if [ -h "${link_target}" ]; then
    rm "${link_target}"
  fi
  run ln -s "${file}" "${link_target}"

  local default=/etc/nginx/sites-enabled/default
  if [ -h "${default}" ]; then
    print_and_log "Configuring the CUE editor: disabling default nginx conf ..."
    run rm "${default}"
  fi

  run service nginx reload
}

_cue_install_web_server() {
  install_packages_if_missing nginx
}

_cue_configure() {
  print_and_log "Configuring the CUE editor: backends ..."
  find /etc/escenic/cue-web-* -maxdepth 0 -type d 2>/dev/null |
    while read -r d; do
      local file="${d}/backends.yml"
      cat > "${file}" <<EOF
# ${file} generated by $(basename "$0") @ $(date)

endpoints:
  escenic: ${fai_cue_backend_ece-/webservice/index.xml}
EOF
      if [ -n "${fai_cue_backend_ng}" ]; then
        echo "  newsgate: ${fai_cue_backend_ece}" >> "${file}"
      fi
    done

  if [ "${on_debian_or_derivative-0}" -eq 1 ]; then
    _cue_configure_debian
  fi

}

_cue_configure_debian() {
  dpkg -l 'cue-web-*' |
    awk '/cue-web/{print $2}' |
    while read -r package; do
      print_and_log "Configuring the CUE editor: ${package} ..."
      run dpkg-reconfigure "${package}"
    done
}

install_cue() {
  print_and_log "Installing the CUE editor on ${HOSTNAME} ..."
  download_escenic_components
  _cue_install_web_server
  _cue_configure
  _cue_setup_cors
}
