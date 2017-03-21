#! /usr/bin/env bash

# by torstein@escenic.com

### get_instance_list
## If the system is installed using the recommended paths, the method
## will return a list of the instances configured in
## ${escenic_conf_dir}/ece-*.conf
function get_instance_list() {
  local allowed_types="engine analysis changelogd search rmi-hub"
  instance_list=""
  for el in $(\ls /etc/escenic/ece-*.conf 2>/dev/null); do

    local instance=$(basename $el .conf)
    instance=${instance##ece-}

    for ele in $allowed_types; do
      if [[ $instance == $ele ]]; then
        instance=""
        continue
      fi

      local away="${ele}-"
      instance=${instance##${away}}
    done
    instance_list="$instance_list $instance"
  done

  echo $instance_list
}

### get_instance_enabled_list
function get_instance_enabled_list() {
  if [ ! -r /etc/default/ece ]; then
    return
  fi

  eval "$(
    source /etc/default/ece &> /dev/null
    declare -p engine_instance_list search_instance_list analysis_instance_list
  )"

  echo ${engine_instance_list} \
    ${search_instance_list} \
    ${analysis_instance_list}
}

### get_instance_tpe
## $1 :: the instance you want to check which type it is.
function get_instance_type() {
  local type="engine"

  if [ -e /etc/default/ece ]; then
    source /etc/default/ece

    for el in "$analysis_instance_list"; do
      if [[ "$(ltrim $el)" == "$1" ]]; then
        type=analysis
      fi
    done

    for el in "$search_instance_list"; do
      if [[ "$(ltrim $el)" == "$1" ]]; then
        type=search
      fi
    done
  fi

  echo $type
}

webapps_in_standard_webapps_list="
  dashboard
  ece-extension
  escenic
  escenic-admin
  indexer-webapp
  indexer-webservice
  inpage-ws
  solr
  studio
  webservice
  webservice-extensions
  newsgate-webservice
  wf-update-service
  video-webservice
  video-webservice-extensions
  poll-ws
  note-webservice
  preview-editor-ws
  mobile-studio
  mobile-webservice
  live-center-editorial
  live-center
  live-center-presentation-webservice
  video-presentation-webservice
  revision-history
  resolver
"

### is_webapp_a_publication
## $1 :: the war file (or just the name of the war file, without the
##       file suffix)
function is_webapp_a_publication() {
  for el in $webapps_in_standard_webapps_list; do
    if [[ "$(basename $1 .war)" == $el ]]; then
      echo 0
      return
    fi
  done

  echo 1
}

### get_app_base
## Will return the app base for the passwed WAR name.
##
## $1 :: the name of the war file
function get_app_base() {
  local war=$(basename $1 .war)

  # this is a list of web applications that are standard ECE related
  # web applications which should not live in their own webapp context
  # (i.e. not a publication).
  for el in $webapps_in_standard_webapps_list; do
    if [[ "$el" == "$war" ]]; then
      echo webapps
      return
    fi
  done

  echo webapps-${war}
}

### get_publication_list
## Returns a list of publications on the local host
##
## $1 :: app server port. Optional, default is 8080.
function get_publication_list() {
  if [ $(which curl | wc -l) -lt 1 ]; then
    return ""
  fi

  curl --silent \
    --connect-timeout 20 \
    http://localhost:${1-8080}/escenic-admin/pages/publication/list.jsp | \
    grep '/escenic-admin/pages/publication/view.jsp' | \
    sed 's/.*name=\(.*\)".*/\1/g'
}

### is_escenic_xml_ok
##
## $1 :: the XML
function is_escenic_xml_ok() {
  if [ ! -e $1 ]; then
    echo 0
    return
  fi

  # first, check for well formed-ness
  xmllint --format $1 > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo 0
    return
  fi

  echo 1
}
