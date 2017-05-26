# -*- mode: sh; sh-shell: bash; -*-
#
# ece-install module for installing Escenic Analysis Engine (EAE),
# also known as "Stats".

_analysis_install_package_if_missing() {
  if [ "${fai_package_enabled-0}" -eq 0 ]; then
    return
  fi

  install_packages_if_missing escenic-analysis-engine
}

_analysis_get_analysis_engine_dir() {
  if [ "${fai_package_enabled-0}" -eq 1 ]; then
    find "${escenic_root_dir}" -name "escenic-analysis-engine*" |
      tail -n -1
  else
    find "${escenic_root_dir}" -maxdepth 1 -name "analysis-engine*" -type d
  fi
}


function install_analysis_server() {
  run_hook install_analysis_server.preinst
  print_and_log "Installing an analysis server on $HOSTNAME ..."

  _analysis_install_package_if_missing

  if [ -n "${fai_analysis_host}" ]; then
    appserver_host=${fai_analysis_host}
  fi
  if [ -n "${fai_analysis_port}" ]; then
    appserver_port=${fai_analysis_port}
  fi

  type=analysis
  install_ece_instance "analysis1"

  # deploy the EAE WARs
  run cp $(_analysis_get_analysis_engine_dir)/wars/*.war \
    ${tomcat_base}/webapps

  set_correct_permissions
  set_up_analysis_conf
  set_up_analysis_plugin_nursery_conf

  run su - $ece_user -c "ece -i ${instance_name} -t ${type} restart"
  run_hook install_analysis_server.postinst
}

## $1 :: WAR
## $2 :: path to file inside WAR
## $3 :: target file
function extract_path_from_war_if_target_file_doesnt_exist() {
  local war=$1
  local path=$2
  local file=$3

  if [ ! -e $file ]; then
    make_dir $(dirname $file)
    (
      run cd $(dirname $file)
      run jar xf $war $path
      run mv $path $file
      run rmdir $(dirname $path)
      run rmdir $(dirname $(dirname $path))
    )
  fi
}

## This is EAE's own configuration, not the ECE plugin part, see
## set_up_analysis_plugin_nursery_conf
function set_up_analysis_conf() {

  # EAE cannot handle .cfg files with quotes values (!)
  dont_quote_conf_values=1

  # First, configure EAE reports
  print_and_log "Configuring EAE Reports ..."
  # extract cfg files if the don't exist already
  local file=${escenic_conf_dir}/analysis/reports.cfg
  local path=WEB-INF/config/reports.cfg
  local war=$(_analysis_get_analysis_engine_dir)/wars/analysis-reports.war
  extract_path_from_war_if_target_file_doesnt_exist $war $path $file

  set_conf_file_value queryServiceUrl \
    http://${appserver_host}:${appserver_port}/analysis-qs/QueryService \
    ${file}

  # Second, configure EAE Logger
  print_and_log "Configuring EAE Logger ..."
  local war=$(_analysis_get_analysis_engine_dir)/wars/analysis-logger.war
  local path=WEB-INF/config/logger.cfg
  local file=${escenic_conf_dir}/analysis/logger.cfg
  extract_path_from_war_if_target_file_doesnt_exist $war $path $file

  set_conf_file_value databaseQueueManager.reinsertcount \
    6 \
    ${file}
  set_conf_file_value pageview.maintenance.cron.expr '0 0 4 * * ? *' $file
  set_conf_file_value pageview.aggr.hour.cron.expr '0 10 * * * ?' $file
  set_conf_file_value imageResponse false $file
  set_conf_file_value pageview.maintenance.older.than.months 6 $file
  set_conf_file_value pageview.aggr.day.older.than.days 7 $file
  set_conf_file_value pageview.aggr.day.cron.expr '0 0 5 * * ? *' $file
  set_conf_file_value pageview.aggr.hour.older.than.hours 2 $file
  set_conf_file_value pageview.maintenance.older.than.days 0 $file

  # Third, configure the EAE query service
  print_and_log "Configuring EAE query service ..."
  local war=$(_analysis_get_analysis_engine_dir)/wars/analysis-qs.war
  local path=WEB-INF/config/qs.cfg
  local file=${escenic_conf_dir}/analysis/qs.cfg
  extract_path_from_war_if_target_file_doesnt_exist $war $path $file

  # important to turn this off here, it's only for the EAE .cfg
  # files, see above.
  dont_quote_conf_values=0
}

function set_up_analysis_plugin_nursery_conf() {
  local file=$common_nursery_dir/com/escenic/analysis/EaePluginConfig.properties
  make_dir $(dirname $file)
  cat > $file <<EOF
\$class=com.escenic.ece.plugin.eae.EaePluginConfig
eaeQsUrl=http://${appserver_host}:${appserver_port}/analysis-qs/QueryService
earUrl=http://${appserver_host}:${appserver_port}/analysis-reports
cacheSize=1000
cacheElementTimeout=2
distinctMetaCountEnabled=false
EOF

  print_and_log "EAE Nursery component configured in $file"
}
