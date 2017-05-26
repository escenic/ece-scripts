#! /usr/bin/env bash

# code for the ece-scripts themselves

function install_ece_scripts_with_git() {
  run cd $download_dir
  if [ -d ece-scripts ]; then
    (
      run cd ece-scripts
      run git pull
    )
  else
    run git clone $ece_scripts_git_source
  fi

  run cp -r ece-scripts/usr/* /usr/
  run cp -r ece-scripts/etc/bash_completion.d/ece /etc/bash_completion.d/
  run cp -r ece-scripts/etc/init.d/* /etc/init.d/

  for el in ece-scripts/etc/default/*; do
    local file=/etc/default/$(basename $el)
    if [ -e $file ]; then
      print_and_log "$file already exists, not overwriting it"
      continue
    fi
    run cp $el /etc/default/
  done

  for el in ece-scripts/etc/escenic/*; do
    local file=/etc/escenic/$(basename $el)
    if [ -e $file ]; then
      print_and_log "$file already exists, not overwriting it"
      continue
    fi
    run cp $el /etc/escenic/
  done
}

function _ece_scripts_install_if_necesary() {
  local -a must_have_list=(
    /etc/default/ece
    /etc/init.d/ece
    /usr/bin/ece
    /usr/share/escenic/ece-scripts
  )

  local missing_anything=0
  for must_have in "${must_have_list[@]}"; do
    if [ ! -e "${must_have}" ]; then
      missing_anything=1
    fi
  done

  if [ "${missing_anything}" -eq 0 ]; then
    return
  fi

  if [ $on_debian_or_derivative -eq 1 ]; then
    install_packages_if_missing escenic-content-engine-scripts
  else
    install_ece_scripts_with_git
  fi
}

function set_up_ece_scripts()
{
  print_and_log 'Setting up the ece UNIX scripts ...'

  _ece_scripts_install_if_necesary

  local file=${escenic_conf_dir}/ece.conf
  local example_ece_conf=/usr/share/doc/escenic/escenic-content-engine-scripts/examples/etc/ece.conf

  # if there's no ece.conf on the system, we assume it's a clean
  # system and we use the ece.conf from the examples directory.
  if [ ! -e $file ]; then
    if [ -e $example_ece_conf ]; then
      print_and_log "The common conf file for /usr/bin/ece," \
        $file "didn't exist on" $HOSTNAME \
        "(I assume a fresh system), copying the one from" $example_ece_conf "..."
      run cp $example_ece_conf $file
    else
      print_and_log $(yellow WARNING) $file "couldn't be found" \
        "and neither could" $example_ece_conf ", you'll have to" \
        "provide a valid ece.conf yourself, e.g. with a conf package"
    fi
  fi
  
  set_conf_file_value assemblytool_home ${escenic_root_dir}/assemblytool $file
  set_conf_file_value backup_dir ${escenic_backups_dir} $file
  set_conf_file_value cache_dir ${escenic_cache_dir} ${file}
  set_conf_file_value data_dir ${escenic_data_dir} ${file}
  set_conf_file_value ece_home ${escenic_root_dir}/engine ${file}
  set_conf_file_value escenic_conf_dir ${escenic_conf_dir} ${file}
  set_conf_file_value heap_dump_dir ${escenic_crash_dir} ${file}
  set_conf_file_value java_home ${java_home} ${file}
  set_conf_file_value log_dir ${escenic_log_dir} ${file}
  set_conf_file_value run_dir ${escenic_run_dir} ${file}
  set_conf_file_value rmi_hub_conf ${escenic_conf_dir}/rmi-hub ${file}
  set_conf_file_value solr_home ${escenic_data_dir}/solr ${file}
  set_conf_file_value ece_security_configuration_dir \
    ${escenic_conf_dir}/engine/common/security \
    ${file}

  file=/etc/bash_completion.d/ece
  run sed -i "s#/etc/escenic#${escenic_conf_dir}#g" $file
  run sed -i "s#/opt/escenic#${escenic_root_dir}#g" $file

  leave_trail "trail_escenic_backups_dir=${escenic_backups_dir}"
}
