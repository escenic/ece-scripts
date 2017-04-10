# ece-install module for installing the RMI hub

function install_rmi_hub()
{
  make_dir $escenic_conf_dir/rmi-hub
  
  run cp -r $(get_content_engine_dir)/contrib/rmi-hub/config/* \
    $escenic_conf_dir/rmi-hub/

  hub_host=$HOSTNAME
  file=$common_nursery_dir
  file=$file/neo/io/managers/HubConnectionManager.properties

  make_dir $(basename $file)
  set_conf_file_value hub \
    "rmi://${hub_host}:1099/hub/Hub" \
    $file

  cat > $common_nursery_dir/io/api/EventManager.properties <<EOF
clientConfiguration=/neo/io/services/HubConnection
pingTime=10000
EOF

  add_next_step "Restart all your instances to make the hub see them."

  print_and_log "Starting the RMI-hub on $HOSTNAME ..."
  ece_command="ece -t rmi-hub restart"
  su - $ece_user -c "$ece_command" 1>>$log 2>>$log
}


