# ece-install module for installing the search server

function install_search_server() {
  print_and_log "Installing a search server on $HOSTNAME ..."
  type=search
  install_ece_instance "search1" 0
  
  multicore_solr_setup 
  assemble_deploy_and_restart_type
  leave_search_server_trail
}

function multicore_solr_setup(){
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
  chown -R escenic:escenic presentation/data/
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
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>60000</maxTime>#g" $file
  fi

  run_hook set_up_solr.postinst

}

function set_up_solr() {
  run_hook set_up_solr.preinst
  
  print_and_log "Setting up Solr ..."
  if [ ! -d $escenic_conf_dir/solr ]; then
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

  local editorial_search_instance=${fai_search_for_editor-0}
  local file=$escenic_conf_dir/solr/solrconfig.xml
  if [ $editorial_search_instance -eq 1 ]; then
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>5000</maxTime>#g" $file
  else
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>60000</maxTime>#g" $file
  fi

  run_hook set_up_solr.postinst
}

function leave_search_server_trail() {
  if [ ${fai_search_install-0} -eq 1 ]; then
    leave_trail "trail_search_port=${fai_search_port-8080}"
    leave_trail "trail_search_shutdown=${fai_search_shutdown-8005}"
  fi
}
