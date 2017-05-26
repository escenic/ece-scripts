function remove_directory_contents_if_exists() {
  if [ -z $1 ]; then
    return
  elif [ ! -d $1 ]; then
    return
  fi

  print_and_log "Restore preparations: removing all files in $1 ..."
  run rm -rf ${1}/*
}

## remove generated files of various sorts, to make the slate as clean
## as possible before restoring a backup
function wipe_the_slate_clean() {
  if [ ${fai_restore_pre_wipe_solr-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_data_dir}/solr/data
  fi
  if [ ${fai_restore_pre_wipe_logs-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_log_dir}
  fi
  if [ ${fai_restore_pre_wipe_cache-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_cache_dir}
  fi
  if [ ${fai_restore_pre_wipe_crash-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_crash_dir}
  fi
}

function restore_from_backup()
{
  local restore_all=0
  local restore_db=0
  local restore_binaries=0
  local restore_data_files=0
  local restore_conf=0
  local backup_file=""
  local backup_dir=$escenic_backups_dir

  wipe_the_slate_clean
  
  if [ ${fai_restore_from_backup-0} -eq 1 ]; then
    print_and_log "Restoring from backup on $HOSTNAME ..."
    
    backup_file=${fai_restore_from_file}

    if [ -z "$backup_file" ]; then
      print_and_log "You must specifify fai_restore_from_file"
      remove_pid_and_exit_in_error
    fi

    if [ ${fai_restore_all-0} -eq 1 ]; then
      restore_all=1
    fi
    
    if [ ${fai_restore_db-0} -eq 1 ]; then
      restore_db=1
    fi
    
    if [ ${fai_restore_data_files-0} -eq 1 ]; then
      restore_data_files=1
    fi
    
    if [ ${fai_restore_software_binaries-0} -eq 1 ]
    then
      restore_binaries=1
    fi
    
    if [ ${fai_restore_configuration-0} -eq 1 ]; then
      restore_conf=1
    fi
  fi

  if [ ! -r "$backup_file" ]; then
    print_and_log "$backup_file either doesn't exist or cannot be read." \
      "I cannot restore from it :-("
    remove_pid_and_exit_in_error
  fi
  
  local dir=$(mktemp -d)
  
  if [ $restore_db -eq 1 -o $restore_all -eq 1 ]; then
    install_database_server "binaries_only"
    print_and_log "Restoring the database contents on $HOSTNAME ..."
    run cd $dir
    if [[ $backup_file == *.sql.gz ]] ; then
      sql_file=$backup_file
    else
      run tar xf $backup_file --wildcards var/backups/escenic/*.sql.gz
        # picking the DB backup file to restore
      sql_file=$(ls -tra var/backups/escenic/*.sql.gz | tail -1)
    fi
    print_and_log "Selecting database dump: $(basename $sql_file)"

    # methods in database.sh to set up the database schema & user
    pre_install_new_ecedb
    create_schema

    # db_schema is defined in database.sh
    gunzip < $sql_file | mysql $db_schema
    exit_on_error "restoring from $sql_file"
    
    add_next_step "$(green Successfully) restored DB from $sql_file"
  fi
  
  if [ $restore_data_files -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the Solr & ECE data files on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file var/lib/escenic
    add_next_step "$(green Successfully) restored Solr & ECE data files" \
      "Backup file used:  $(basename $backup_file)" \
      "Check $escenic_data_dir to verify they're all there."
  fi
  
  if [ $restore_conf -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the ECE configuration files on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file etc
    add_next_step "$(green Successfully) restored ECE configuration files" \
      "Backup file used: $(basename $backup_file)" \
      "Check /etc to verify that they're all there."
  fi
  
  if [ $restore_binaries -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the Escenic & Tomcat binaries on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file opt
    add_next_step "$(green Successfully) restored Escenic & Tomcat binaries" \
      "Backup file used: $(basename $backup_file)" \
      "Check ${appserver_parent_dir} to verify that they're all there".
    install_ece_third_party_packages
    set_up_engine_directories

    # doing some educated guessing on which tomcat_base/home as well
    # as UNIX user/group to use for this.
    file=/etc/default/ece
    if [ -r $file ]; then
      ece_user=$(grep ^ece_unix_user $file | \
        cut -d'=' -f2 | \
        sed -e "s/'//g" -e 's/"//g'
      )
      ece_group=$(grep ^ece_unix_group $file | \
        cut -d'=' -f2 | \
        sed -e "s/'//g" -e 's/"//g'
      )
      create_user_and_group_if_not_present $ece_user $ece_group
      
      if [ -d $escenic_conf_dir -a \
        $(ls $escenic_conf_dir/ | grep ^ece- | wc -l) -gt 0 -a \
        $(grep ^tomcat_base $escenic_conf_dir/ece*.conf | wc -l) -gt 0 ]; then
        directories=$(grep ^tomcat_base $escenic_conf_dir/ece*.conf | \
          cut -d'=' -f2 | \
          sed -e "s/'//g" -e 's/"//g'
        )
        s="Setting file permissions according to /etc/default/ece"
        print_and_log $s
        s="and $escenic_conf_dir/ece*.conf"
        print_and_log $s
        for el in ${directories}; do
          if [ ! -d $el ]; then
            continue
          fi
          run chown -R ${ece_user}:${ece_group} ${el}
        done  
      fi
    fi
  fi
}
