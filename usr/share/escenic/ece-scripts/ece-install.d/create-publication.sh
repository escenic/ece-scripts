## If the user has fai_publication_war_remove_file_list set, these
## files will, if present, be removed from the WAR file.
##
## $1 :: full path to the WAR file
function create_publication_prepare_war_file() {
  if [ -n "${fai_publication_war_remove_file_list}" ]; then
    local the_tmp_dir=$(mktemp -d)
    (
      cd $the_tmp_dir
      #run jar xf $1

      for el in $fai_publication_war_remove_file_list; do
        if [ -e $el ]; then
          print_and_log "Removing" $el "from" $(basename $1) "..."
          #run rm $el
          zip -d $1 $el
        fi
      done

      #run jar cf $1 .
    )
  fi
}

function create_publication() {
  print_and_log "Preparing publication creation ..."

  if [ ${fai_enabled-0} -eq 1 ]; then
    # figure out which WAR to use for the publication creation
    local publication_war=""
    if [ -n "${fai_publication_ear}" ]; then
      print_and_log "I will create all publications in" \
        $fai_publication_ear "using the the domain mapping list ..."

      ensure_variable_is_set fai_publication_domain_mapping_list
      local the_tmp_dir=$(mktemp -d)

      # we're using the builder HTTP crendentials, if set, for
      # downloading the EAR.
      if [[ -n "${fai_builder_http_user}" && \
        -n "${fai_builder_http_password}" ]]; then
        wget_auth="
          --http-user $fai_builder_http_user
          --http-password $fai_builder_http_password
        "
      fi
      download_uri_target_to_dir $fai_publication_ear $download_dir
      (
        run cd $the_tmp_dir
        run jar xf $download_dir/$(basename $fai_publication_ear)
      )

      ensure_that_instance_is_running ${fai_publication_use_instance-$default_ece_intance_name}
      for el in ${fai_publication_domain_mapping_list}; do
        local old_ifs=$IFS
        # the entries in the fai_publication_domain_mapping_list are on
        # the form: <publication[,pub.war]>#<domain>[#<alias1>[,<alias2>]]
        IFS='#' read publication domain aliases <<< "$el"
        IFS=',' read publication_name publication_war publication_type <<< "$publication"
        IFS=$old_ifs

        # this is the default case were the WAR is called the same as
        # the publication name with the .war suffix.
        if [ -z "${publication_war}" ]; then
          publication_war=${publication_name}.war
        fi

        create_the_publication $publication_name $the_tmp_dir/$publication_war $publication_type
      done

      log "Cleaing up $the_tmp_dir ..."
      run rm -rf $the_tmp_dir
    else
      ensure_that_instance_is_running ${fai_publication_use_instance-$default_ece_intance_name}
      local publication_name=${fai_publication_name-mypub}
      local publication_type=${fai_publication_type-default}

      if [ -z "${fai_publication_war}" ]; then
        # if the user hasn't set the fai_publication_war, see if the
        # demo-clean.war is available on the system.
        local file=$escenic_root_dir/engine/contrib/wars/demo-clean.war
        if [ -e $file ]; then
          publication_war=$file
        else
          # if neither fai_publication_war nor demo-clean.war are
          # available make the installation fail and inform the user
          # of the need to set fai_publication_war
          ensure_variable_is_set fai_publication_war
        fi
      else
        publication_war=$fai_publication_war
      fi

      create_the_publication $publication_name $publication_war $publication_type
    fi
  fi
}

## $1 :: publication name
## $2 :: publication war
function create_the_publication() {
  local publication_name=$1
  local publication_war=$2
  local publication_type=$3

  print_and_log "Creating a publication with name" $publication_name of $publication_type type \
    "using the publication resources from" $(basename $publication_war)

  create_publication_prepare_war_file $publication_war
  local the_instance=${fai_publication_use_instance-$default_ece_intance_name}
  create_publication_in_db $publication_name $publication_war $publication_type $the_instance
  add_publication_to_deployment_lists $(basename $publication_war .war)

  add_next_step "A publication with name" $publication_name \
    "has been created using the publication resources in" \
    $publication_war "The WAR has been added to the deployment" \
    "white list, so that it will be included next time you do" \
    "ece -i ${the_instance} deploy"
}

## $1 : publication WAR name
function add_publication_to_deployment_lists() {
  run source /etc/default/ece
  local please_add=1

  for el in $engine_instance_list; do
    local file=/etc/escenic/ece-${el}.conf
    run source $file

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
      $file
  done
}

## $1 :: the instance name
function ensure_that_instance_is_running() {
  local ece_command="ece -i $1 -t $type status"
  if [ $(su - $ece_user -c "$ece_command" | grep UP | wc -l) -lt 1 ]; then
    ece_command="ece -i $1 -t $type start"
    su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  fi

  # This is a hack, but this ensures that the ECE is bootstrapped
  # properly and can respond fast enough to the session setup for the
  # publication creation.
  ece_command="ece -i $1 -t $type versions"
  su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  sleep 60
}

## $1 :: publication name
## $2 :: publication war
## $3 :: instance name
##
## Based on Erik Mogensen's work:
## //depot/branches/personal/mogsie/fromscratch/create-publication.sh
function create_publication_in_db() {
  local publication_name=$1
  local publication_war=$2
  local publication_type=$3
  local instance_name=$4

  print_and_log "Creating publication" ${publication_name} \
    "using instance" $instance_name "..."

  # sourcing the instance's ECE configuration to get the app server
  # port.
  run source /etc/escenic/ece-${instance_name}.conf

  local ece_admin_uri=http://localhost:${appserver_port}/escenic-admin

  local cookie=$(curl ${curl_opts} -I ${ece_admin_uri}/ | \
    grep -i "^Set-Cookie" | \
    sed s/.*'JSESSIONID=\([^;]*\).*'/'\1'/)

  if [[ "$cookie" == "" ]] ; then
    print_and_log "Unable to get a session cookie from instance $instance_name"
    exit 1
  fi

  run curl ${curl_opts} \
    -F "type=webapp" \
    -F "resourceFile=@${publication_war}" \
    --cookie JSESSIONID="$cookie" \
    "${ece_admin_uri}/do/publication/resource"

  run curl ${curl_opts}  \
    -F "name=${publication_name}" \
    -F "publisherName=Escenic" \
    -F "publicationType=${publication_type}" \
    -F "adminPassword=admin" \
    -F "adminPasswordConfirm=admin" \
    --cookie JSESSIONID="$cookie" \
    "${ece_admin_uri}/do/publication/insert"
}
