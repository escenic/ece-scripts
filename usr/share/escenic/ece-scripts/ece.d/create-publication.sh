# -*- mode: sh; sh-shell: bash; -*-

## Sub comamnd for /usr/bin/ece
##
## Creates a publication in the ECE DB and optionally:
## - configures Tomcat's server.xml
## - configures Nursery
##
## author: torstein@escenic.com

_create_publication_tmp_dir=/tmp

## Method that tries to ensure that there's a valid publication
## archive from which to create the publication.
##
## Reads and writes the global variable 'file'.
_create_publication_find_par_if_none_has_been_specified() {
  if [ -n "${file}" ]; then
    return
  fi

  local par=
  par=$(
    find /usr/share/escenic/escenic-content-engine-* \
         -maxdepth 3 \
         -name demo-clean.war 2>/dev/null)

  if [[ -n "${par}" && -r "${par}" ]]; then
    file=${par}
  fi
}

## Adding the publication to the deployment white list of all ECE
## instances on the machine.
##
## $1 : publication name
_create_publication_add_publication_to_deployment_lists() {
  run source /etc/default/ece
  local please_add=1
  local el=

  for el in ${engine_instance_list}; do
    local instance_conf=/etc/escenic/ece-${el}.conf
    run source ${instance_conf}

    for ele in $deploy_webapp_white_list; do
      if [[ "$ele" == "$1" ]]; then
        please_add=0
      fi
    done

    if [ $please_add -eq 1 ]; then
      print_and_log "Adding $1 to the deploy white list of" \
                    "instance" $el
      deploy_webapp_white_list="$deploy_webapp_white_list $1"
    fi

    set_conf_file_value \
      deploy_webapp_white_list \
      $deploy_webapp_white_list \
      $instance_conf
  done
}

## $@ :: args passed to /usr/bin/ece
_create_publication_parse_use_input() {
  ## Only parsing options that are special to us. The common ones have
  ## already been parsed
  local user_options=$(
    getopt -o \
           a:nd:est: \
           --long help \
           --long publication-domain: \
           --long publication-type: \
           --long publication-aliases: \
           --long update-app-server-conf \
           --long update-ece-conf \
           --long update-nursery-conf \
           -n 'parse-options' \
           --quiet \
           -- "$@")

  if [ $? != 0 ] ; then print "Failed parsing options." ; exit 1 ; fi
  eval set -- "$user_options"

  while true; do
    case "$1" in
      -s | --update-app-server-conf)
        update_app_server_conf=1
        shift 1;;
      -d | --publication-domain)
        publication_domain="$2";
        shift 2;;
      -t | --publication-type)
        publication_type="$2";
        shift 2;;
      -a | --publication-aliases)
        publication_aliases="$2";
        shift 2;;
      -n | --update-nursery-conf)
        update_nursery_conf=1
        shift 1;;
      -e | --update-ece-conf)
        update_ece_conf=1
        shift 1;;
      -- ) shift; break ;;
      * ) break ;;
    esac
  done

  if [ -z "${publication}" ]; then
    print "You must specify --publication <name>"
    exit 1
  fi

  _create_publication_find_par_if_none_has_been_specified "${file}"

  if [ -z "${file}" ]; then
    print "You must specify --file <name> or --uri <uri>"
    exit 1
  else
    download_uri_target_to_dir "${file}" "${_create_publication_tmp_dir}"
    publication_war="${_create_publication_tmp_dir}/${file##*/}"
  fi
}

## $1 :: publication name
## $2 :: instance name
_create_publication_already_exists() {
  local publication_name=$1
  local instance_name=$2
  ece -i "${instance_name}" list-publications |
    grep --silent --word-regexp "${publication_name}"
}


## Uses /escenic-admin of a running ECE instance to create the
## publication. If the publication already exists, this method will do
## nothing (i.e. it'll not fail, just silently refrain from doing any
## actual change. This decision is done on /escenic-admin).
##
## Based on Erik Mogensen's work:
## //depot/branches/personal/mogsie/fromscratch/create-publication.sh
##
## $1 :: publication name
## $2 :: publication war
## $3 :: instance type
## $4 :: instance name
_create_publication_create_publication_in_db() {
  local publication_name=$1
  local publication_war=$2
  local publication_type=$3
  local instance_name=$4

  if _create_publication_already_exists "${publication_name}" "${instance_name}"; then
    return
  fi

  if [ ! -e "${publication_war}" ]; then
    print_and_log "Need valid publication WAR/PAR to create publication," \
                  "you passed publication_war=${publication_war}"
    exit 1
  fi

  print "Creating publication ${publication} ..."
  log "Creating publication ${publication} using instance ${instance_name}" \
      "and ${publication_war}"

  # sourcing the instance's ECE configuration to get the app server
  # port.
  run source "/etc/escenic/ece-${instance_name}.conf"
  local ece_admin_uri=http://localhost:${appserver_port}/escenic-admin
  local cookie=
  cookie=$(
    curl \
      "${curl_appserver_auth}" \
      --head "${ece_admin_uri}"/ \
      --silent |
      grep -i "^Set-Cookie" |
      sed s/.*'JSESSIONID=\([^;]*\).*'/'\1'/)

  if [[ "$cookie" == "" ]] ; then
    print_and_log "Unable to get a session cookie from instance $instance_name"
    exit 1
  fi

  run curl \
      "${curl_appserver_auth}" \
      -F "type=webapp" \
      -F "resourceFile=@${publication_war}" \
      --cookie JSESSIONID="${cookie}" \
      "${ece_admin_uri}/do/publication/resource"

  run curl  \
      "${curl_appserver_auth}" \
      -F "name=${publication_name}" \
      -F "publisherName=Escenic" \
      -F "publicationType=${publication_type}" \
      -F "adminPassword=admin" \
      -F "adminPasswordConfirm=admin" \
      --cookie JSESSIONID="${cookie}" \
      "${ece_admin_uri}/do/publication/insert"
}


_create_publication_update_app_server_conf() {
  server_xml=/opt/tomcat-${instance}/conf/server.xml
  if [ ! -e "${server_xml}" ]; then
    return
  fi

  local current_pub_conf_in_app_server=
  current_pub_conf_in_app_server=$(
    lookup_in_xml_file \
      "${server_xml}" \
      "/Server/Service/Engine/Host/Context[@displayName='${publication}']" \
      2>/dev/null)

  if [ -n "${current_pub_conf_in_app_server}" ]; then
    log "App server for ${instance} already has conf for ${publication}"
    return
  fi

  print_and_log "Updating app server config of instance ${instance} ..."
  xmlstarlet \
    ed \
    -P \
    -L \
    -s /Server/Service/Engine -t elem -n TMP -v '' \
    -i /Server/Service/Engine/TMP -t attr -n name -v "${publication}.${HOSTNAME}" \
    -i /Server/Service/Engine/TMP -t attr -n appBase -v "webapps-${publication}" \
    -i /Server/Service/Engine/TMP -t attr -n autoDeploy -v "true" \
    -i /Server/Service/Engine/TMP -t attr -n startStopThreads -v "0" \
    -r //TMP -v Host \
    -s "/Server/Service/Engine/Host[@name='${publication}.${HOSTNAME}']" -t elem -n TMP -v "${publication}.${HOSTNAME}" \
    -r //TMP -v Alias \
    -s "/Server/Service/Engine/Host[@name='${publication}.${HOSTNAME}']" -t elem -n TMP -v '' \
    -i //TMP -t attr -n displayName -v "${publication}" \
    -i //TMP -t attr -n docBase -v "${publication}" \
    -i //TMP -t attr -n path -v "" \
    -r //TMP -v Context \
    "${server_xml}"

  local old_ifs=$IFS
  local an_alias=
  IFS=,
  for an_alias in ${publication_aliases}; do
    xmlstarlet \
      ed \
      -P \
      -L \
      -s "/Server/Service/Engine/Host[@name='${publication}.${HOSTNAME}']" -t elem -n TMP -v "${an_alias}" \
      -r //TMP -v Alias \
      "${server_xml}"
  done
  IFS=$old_ifs

  # make it pretty
  xmllint --format "${server_xml}" > "${server_xml}.pretty"
  run mv "${server_xml}.pretty" "${server_xml}"
}

_create_publication_create_nursery_conf() {
  local nursery_file=${escenic_conf_dir-/etc/escenic}/engine/common/neo/publications/Pub-${publication}.properties
  if [ -e "${nursery_file}" ]; then
    log "Nursery component ${nursery_file} already exists, hands off."
    return
  fi

  if [ -z "${publication_domain}" ]; then
    print_and_log "INFO: No publication domain speciced, not creating Nursery" \
                  "component, if you wish to add one, specify it with" \
                  "--publication-domain <domain>"
    return
  else
    print_and_log "Creating Nursery component ${nursery_file}"
  fi

  run mkdir -p "${nursery_file%/*}"

  cat > "${nursery_file}" <<EOF
# Created by ${BASH_SOURCE[0]##*/} @ $(date)
\$class=neo.xredsys.config.SimplePublicationSupport
url=http://${publication_domain}/
EOF
}

## Provides auto completion options for this command. Should match
## what's in _create_publication_parse_use_input
complete_create_publication() {
  cat <<EOF
--publication-aliases
--publication-domain
--publication-type
--update-app-server-conf
--update-ece-conf
--update-nursery-conf
--file
--uri
-a
-d
-e
-n
-s
EOF
}

## Main method called from /usr/bin/ece
##
## $@ :: the arg list from /usr/bin/ece
cmd_create_publication() {
  _create_publication_parse_use_input "${@}"
  _create_publication_create_publication_in_db \
    "${publication}" \
    "${publication_war}" \
    "${publication_type-default}" \
    "${instance}"

  if [ ${update_app_server_conf-0} -eq 1 ]; then
    _create_publication_update_app_server_conf
  fi
  if [ ${update_nursery_conf-0} -eq 1 ]; then
    _create_publication_create_nursery_conf
  fi
  if [ ${update_ece_conf-0} -eq 1 ]; then
    _create_publication_add_publication_to_deployment_lists "${publication}"
  fi
}

# root is allowed to run this command
export root_allowed_create_publication=1
