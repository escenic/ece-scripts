# ece-install module for installing the search server

solr_download_url=https://archive.apache.org/dist/lucene/solr/6.1.0/solr-6.1.0.zip

## Since solr itself talks about SOLR_HOME as where it has its data
## files (solr_data_dir might have been a more suitable name), we
## cannot use solr_home as we e.g. use java_home, but instead use
## this:
solr_dir=/opt/solr

function install_search_server() {
  print_and_log "Installing a search server on $HOSTNAME ..."
  type=search
  install_ece_instance "search1" 0

  if [ ${fai_search_legacy-0} -eq 0 ]; then
    set_up_solr
  else
    multicore_solr_setup_pre_ece6
  fi
  assemble_deploy_and_restart_type
  leave_search_server_trail
}

function multicore_solr_setup_pre_ece6(){
  run_hook set_up_solr.preinst

  print_and_log "Setting up  Multicore Solr ..."
  if [ ! -d $escenic_conf_dir/solr ]; then
    if [ $(is_using_conf_archive) -eq 1 ]; then
      print_and_log "Using the supplied Solr configuration from" \
        "bundle: $ece_instance_conf_archive"

      # the conf archive typically resides on the build server, hence
      # we set its authentication credentials here.
      wget_auth=$wget_builder_auth
      print_and_log "ece_instance_conf_archive value is : $ece_instance_conf_archive"
      local a_tmp_dir=$(mktemp -d)
      download_uri_target_to_dir \
        $ece_instance_conf_archive \
        $a_tmp_dir
      local file=$a_tmp_dir/$(basename $ece_instance_conf_archive)

      run cd $a_tmp_dir
      run tar xzf $(basename $ece_instance_conf_archive) engine/solr/conf
      run cp -r engine/solr/conf $escenic_conf_dir/solr

      run rm -r $a_tmp_dir
    else
      print_and_log "Installing default Solr conf shipped with ECE ..."
      run cp -r $escenic_root_dir/engine/solr/conf $escenic_conf_dir/solr
      
      # ECE 5.6 has one additional configuration file!
      if [ -e $escenic_root_dir/engine/solr/solr.xml ]; then
        run cp -r $escenic_root_dir/engine/solr/solr.xml $escenic_conf_dir/. 
      fi
    fi
  else
    print_and_log "$escenic_conf_dir/solr already exists, not touching it."
  fi

  make_dir $escenic_data_dir/solr/
  run cd $escenic_data_dir/solr/
  if  [ ! -h conf ]; then
    run ln -s $escenic_conf_dir/solr conf
  fi
  # ECE 5.6 has one additional configuration file!
  if  [ ! -h solr.xml ]; then
    if [ -e $escenic_conf_dir/solr.xml ]; then
      run ln -s $escenic_conf_dir/solr.xml solr.xml
    fi
  fi

  run xmlstarlet ed -L -s //solr/cores -t elem -n CoreTMP -v "" \
    -i //CoreTMP -t attr -n "name" -v "presentation" \
    -i //CoreTMP -t attr -n "instanceDir" -v "presentation" \
    -r //CoreTMP -v core \
    solr.xml
  
  print_and_log "Added presentation solr core configuration directroy"  

  make_dir presentation/conf
  make_dir presentation/data/index
  run chown -R ${ece_user}:${ece_group} presentation/data/
  run cp -r $escenic_conf_dir/solr/*  presentation/conf/

  run xmlstarlet ed -L -s //config -t elem -n DataTMP -v "$escenic_data_dir/solr/presentation/data" \
       -r //DataTMP -v dataDir \
   $escenic_data_dir/solr/presentation/conf/solrconfig.xml
  print_and_log "Finished adding configuration for multicore solr"
  
  local editorial_search_instance=${fai_search_for_editor-0}
  local file=$escenic_conf_dir/solr/solrconfig.xml
  if [ $editorial_search_instance -eq 1 ]; then
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>5000</maxTime>#g" $file
  else
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>3000</maxTime>#g" $file
  fi

  run_hook set_up_solr.postinst

}

function download_and_install_solr() {
  local file=
  local solr_base_dir=

  solr_base_dir=$(basename ${solr_download_url} .zip)
  if [ -e "/opt/${solr_base_dir}" ]; then
    print_and_log "Solr dir, /opt/${solr_base_dir}, already exists, leaving it be."
    return
  fi

  print "Downloading Solr from ${solr_download_url} ..."
  download_uri_target_to_dir "${solr_download_url}" "${download_dir}"

  file="${download_dir}"/$(basename ${solr_download_url})
  run unzip -q "${file}" -d /opt
  run chown -R "${ece_user}":"${ece_group}" "/opt/${solr_base_dir}"

  if [ ! -h ${solr_dir} ]; then
    run ln -s "/opt/${solr_base_dir}" ${solr_dir}
  fi
}

function create_global_solr_configuration() {
  local file=/etc/default/solr.in.sh
  if [ -e ${file} ]; then
    print_and_log "${file} already exists, not touching it"
  else
    print "Creating global solr config in ${file} ..."
    run mv ${solr_dir}/bin/solr.in.sh "${file}"
    cat >> ${file} <<EOF
## Added by $(basename $0) @ $(date)
SOLR_HOME=${escenic_data_dir/solr}
SOLR_LOGS_DIR=${escenic_log_dir}
SOLR_PID_DIR=${escenic_run_dir}
EOF
  fi
}

function setup_solr_init_d_script() {
  local init_d_file=/etc/init.d/solr
  if [ -e "${init_d_file}" ]; then
    print_and_log "${init_d_file} already exists, keeping my hands off"
    return
  fi

  print_and_log "Setting up init.d script: ${init_d_file}"
  run mv "${solr_dir}/bin/init.d/solr" "${init_d_file}"
  run sed -i "s#RUNAS=\"solr\"#RUNAS=\"${ece_user}\"#" "${init_d_file}"
  run chmod 755 "${init_d_file}"

  if [ "${on_debian_or_derivative}" -eq 1 ]; then
    print_and_log "Adding the solr init.d script to the default run levels ..."
    run update-rc.d solr defaults 35
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    print_and_log "Adding the solr init.d script to the default run levels ..."
    run chkconfig --level 35 solr on
  fi
}

function start_solr() {
  run /etc/init.d/solr start
}

function set_up_solr() {
  run_hook set_up_solr.preinst

  local solr_core_list="
    editorial
    presentation
  "

  print_and_log "Setting up Solr ..."
  download_and_install_solr
  create_global_solr_configuration
  setup_solr_init_d_script

  if [ ! -d $escenic_conf_dir/solr ]; then
    make_dir "$escenic_conf_dir/solr"

    if [ $(is_using_conf_archive) -eq 1 ]; then
      print_and_log "Using the supplied Solr configuration from" \
        "bundle: $ece_instance_conf_archive"
      
      # the conf archive typically resides on the build server, hence
      # we set its authentication credentials here.
      wget_auth=$wget_builder_auth
      local a_tmp_dir=$(mktemp -d)
      download_uri_target_to_dir \
        $ece_instance_conf_archive \
        $a_tmp_dir
      local file=$a_tmp_dir/$(basename $ece_instance_conf_archive)

      run cd $a_tmp_dir
      run tar xzf $(basename $ece_instance_conf_archive) engine/solr/conf

      for solr_core in ${solr_core_list}; do
        run cp -r engine/solr/conf "$escenic_conf_dir/solr/${solr_core}"
      done

      run rm -r "${a_tmp_dir}"
    else
      print_and_log "Installing default Solr conf shipped with ECE ..."

      for solr_core in ${solr_core_list}; do
        run cp -r "$escenic_root_dir/engine/solr/conf" "$escenic_conf_dir/solr/${solr_core}"
      done
    fi
  else
    print_and_log "$escenic_conf_dir/solr already exists, not touching it."
  fi

  local solr_xml="${escenic_data_dir}/solr.xml"
  if [ -f "${solr_xml}" ]; then
    print_and_log "${escenic_conf_dir}/solr.xml already exists, not touching it."
  else
    local target_solr_xml=/etc/escenic/solr.xml
    print_and_log "Setting up solr.xml in ${target_solr_xml}"
    run cp ${solr_dir}/server/solr/solr.xml "${target_solr_xml}"
    run ln -s "${target_solr_xml}" "${escenic_data_dir}/solr.xml"
  fi

  for solr_core in ${solr_core_list}; do
    make_dir "$escenic_data_dir/solr/${solr_core}"
    run cd "$escenic_data_dir/solr/${solr_core}"
    if  [ ! -h conf ]; then
      run ln -s "$escenic_conf_dir/solr/${solr_core}" conf
    fi

    create_solr_core_descriptor "${solr_core}"

    ## backwards compatible: respect editorial_search_instance
    local editorial_search_instance=${fai_search_for_editor-0}

    if [ ${editorial_search_instance} -eq 0 ]; then
      if [[ "editorial" == "${solr_core}" ]]; then
        editorial_search_instance=1
      fi
    fi
    local file=$escenic_conf_dir/solr/${solr_core}/solrconfig.xml
    if [ ${editorial_search_instance} -eq 1 ]; then
      run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>5000</maxTime>#g" $file
    else
      run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>3000</maxTime>#g" $file
    fi
  done

  run chown -R "${ece_user}:${ece_group}" "${escenic_data_dir}/solr"
  start_solr
  run_hook set_up_solr.postinst
}

## $1 :: solr core name
function create_solr_core_descriptor() {
  local solr_core=$1

  ## Can't be in the conf directory as solr will then try to prepend
  ## conf.
  local core_descriptor="${escenic_data_dir}/solr/${solr_core}/core.properties"
  print_and_log "Creating core descirptor: ${core_descriptor}"
  cat > ${core_descriptor} <<EOF
## generated by $(basename $0) @ $(date)
name=${solr_core}
config=solrconfig.xml
schema=schema.xml
dataDir=data
EOF
}

function leave_search_server_trail() {
  if [ ${fai_search_install-0} -eq 1 ]; then
    leave_trail "trail_search_port=${fai_search_port-8080}"
    leave_trail "trail_search_shutdown=${fai_search_shutdown-8005}"
  fi
}
