# -*- mode: sh; sh-shell: bash; -*-

## imports
source "${BASH_SOURCE[0]%/*}/../common-os.sh"

## $1 :; YAML file
is_yaml() {
  local yaml_file=$1
  json_xs < "${yaml_file}" -f yaml -t json &> /dev/null || {
    return 1
  }

  return 0
}


## Will parse the YAML file and set the corresponding fai_ parameters
## that ece-install uses internally. Old ece-install.conf style files
## are still supported: if ece-install cannot recognoise the file as
## YAML it'll assume it's in the old format and will source it.
##
## $1 :: YAML file.
parse_yaml_conf_file_or_source_if_sh_conf() {
  assert_commands_available json_xs jq

  local yaml_file=$1

  if ! is_yaml "${yaml_file}" ; then
    local suffix=${yaml_file##*.}
    if [[ "${suffix}" == yaml ]]; then
      print_and_log "Conf file ${yaml_file} isn't valid YAML," \
                    "see ${log} for further details"
      json_xs < "${yaml_file}" -f yaml -t json &>> "${log}"
      remove_pid_and_exit_in_error
    else
      source "${yaml_file}"
    fi
    return
  fi

  _parse_yaml_conf_file_editor "${yaml_file}"
  _parse_yaml_conf_file_presentation "${yaml_file}"
  _parse_yaml_conf_file_search "${yaml_file}"
  _parse_yaml_conf_file_db "${yaml_file}"
  _parse_yaml_conf_file_analysis_db "${yaml_file}"
  _parse_yaml_conf_file_cache "${yaml_file}"
  _parse_yaml_conf_file_analysis "${yaml_file}"
  _parse_yaml_conf_file_credentials "${yaml_file}"
  _parse_yaml_conf_file_publications "${yaml_file}"
  _parse_yaml_conf_file_packages "${yaml_file}"
  _parse_yaml_conf_file_environment "${yaml_file}"
  _parse_yaml_conf_file_monitoring "${yaml_file}"
  _parse_yaml_conf_file_assembly_tool "${yaml_file}"
  _parse_yaml_conf_file_restore "${yaml_file}"
  _parse_yaml_conf_file_cue "${yaml_file}"
  _parse_yaml_conf_file_nfs_server "${yaml_file}"
  _parse_yaml_conf_file_nfs_client "${yaml_file}"
}

_parse_yaml_conf_file_credentials() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".credentials | length")
  for ((i = 0; i < count; i++)); do
    local user=
    local password=
    local site=
    site=$(_jq "${yaml_file}" .credentials["${i}"].site)
    user=$(_jq "${yaml_file}" .credentials["${i}"].user)
    password=$(_jq "${yaml_file}" .credentials["${i}"].password)
    if [[ "${site}" == maven.escenic.com ]]; then
      export technet_user=${user}
      export technet_password=${password}
    fi
    if [[ "${site}" == builder ]]; then
      export fai_builder_http_user=${user}
      export fai_builder_http_password=${password}
      export fai_conf_builder_http_user=${user}
      export fai_conf_builder_http_password=${password}
    fi
    if [[ "${site}" == yum.escenic.com ||
            "${site}" == unstable.yum.escenic.com ]]; then
      export fai_package_rpm_user=${user}
      export fai_package_rpm_password=${password}
    fi
    if [[ "${site}" == apt.escenic.com ||
            "${site}" == unstable.apt.escenic.com ]]; then
      export fai_package_apt_user=${user}
      export fai_package_apt_password=${password}
    fi
  done
}

_parse_yaml_conf_file_publications() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".profiles.publications | length")

  fai_publication_domain_mapping_list=""

  for ((i = 0; i < count; i++)); do

    local name=
    local war=
    local ear=
    local webapps=
    local domain=
    local aliases=
    local environment=
    local war_remove_list=
    local update_app_server_conf=
    local update_ece_conf=
    local update_nursery_conf=

    create=$(_jq "${yaml_file}" .profiles.publications["${i}"].create)
    ear=$(_jq "${yaml_file}" .profiles.publications["${i}"].ear)
    name=$(_jq "${yaml_file}" .profiles.publications["${i}"].name)
    war=$(_jq "${yaml_file}" .profiles.publications["${i}"].war)
    environment=$(_jq "${yaml_file}" .profiles.publications["${i}"].environment)

    update_app_server_conf=$(
      _jq "${yaml_file}" .profiles.publications["${i}"].update_app_server_conf)
    update_ece_conf=$(
      _jq "${yaml_file}" .profiles.publications["${i}"].update_ece_conf)
    update_nursery_conf=$(
      _jq "${yaml_file}" .profiles.publications["${i}"].update_nursery_conf)

    # If there are one or more publications defined in 'publications'
    # with these settings, we assume the user wants to create all
    # publications.
    #
    # FYI: It's safe to re-run creation for existing publications.
    if [[ "${create}" == true || "${create}" == yes ]]; then
      export fai_publication_create=1
    fi
    if [[ "${update_nursery_conf}" == true ||
            "${update_nursery_conf}" == yes ]]; then
      export fai_publication_update_nursery_conf=1
    fi
    if [[ "${update_ece_conf}" == true ||
            "${update_ece_conf}" == yes ]]; then
      export fai_publication_update_ece_conf=1
    fi
    if [[ "${update_app_server_conf}" == true ||
            "${update_app_server_conf}" == yes ]]; then
      export fai_publication_update_app_server_conf=1
    fi

    if [ -z "${war}" ]; then
      export war=${name}.war
    fi
    if [ -n "${ear}" ]; then
      export fai_publication_ear=${ear}
    fi
    if [ -n "${environment}" ]; then
      export fai_publication_environment="${environment}"
    fi

    domain=$(_jq "${yaml_file}" .profiles.publications["${i}"].domain)
    alias_count=$(_jq "${yaml_file}" ".profiles.publications[${i}].aliases | length")
    for ((j = 0; j < alias_count; j++)); do
      if [ -n "${aliases}" ]; then
        aliases="${aliases},"
      fi
      aliases=${aliases}$(_jq "${yaml_file}" .profiles.publications["${i}"].aliases["${j}"])
    done

    webapps_count=$(_jq "${yaml_file}" ".profiles.publications[${i}].webapps | length")
    for ((j = 0; j < webapps_count; j++)); do
      if [ -n "${webapps}" ]; then
        webapps="${webapps} "
      fi
      webapps=${webapps}$(_jq "${yaml_file}" .profiles.publications["${i}"].webapps["${j}"])
    done
    export fai_publication_webapps=${webapps}
    export fai_publications_webapps=${fai_publication_webapps}

    war_remove_list_count=$(
      _jq "${yaml_file}" ".profiles.publications[${i}].war_remove_list | length")
    for ((j = 0; j < war_remove_list_count; j++)); do
      if [ -n "${war_remove_list}" ]; then
        war_remove_list="${war_remove_list} "
      fi
      war_remove_list=${war_remove_list}$(
        _jq "${yaml_file}" .profiles.publications["${i}"].war_remove_list["${j}"])
    done
    export fai_publication_war_remove_file_list=${war_remove_list}

    fai_publication_domain_mapping_list="
      ${fai_publication_domain_mapping_list}
      ${name},${war}#${domain}"

    if [ -n "${aliases}" ]; then
      fai_publication_domain_mapping_list=${fai_publication_domain_mapping_list}"#${aliases}"
    fi
  done

  export fai_publication_domain_mapping_list

}

## Populates the global variable fai_package_map with package names
## and (optionally) versions.
##
## Developer's note: This associative array is declared in this
## module, but if it for reason is unset by the caller, the caller
## must re-initialise it too (as is done in the unit tests).
_parse_yaml_conf_file_packages() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".packages | length")

  for ((i = 0; i < count; i++)); do
    local name=
    local version=
    local arch=
    name=$(_jq "${yaml_file}" .packages["${i}"].name)
    version=$(_jq "${yaml_file}" .packages["${i}"].version)
    arch=$(_jq "${yaml_file}" .packages["${i}"].arch)
    fai_package_map[${name}]=${version}
    fai_package_arch_map[${name}]=${arch}
    export fai_package_enabled=1
    export escenic_root_dir=/usr/share/escenic
  done
}

_parse_yaml_conf_file_editor() {
  local yaml_file=$1

  local install_editor=no
  install_editor=$(_jq "${yaml_file}" .profiles.editor.install)
  if [[ "${install_editor}" == "yes" ||
          "${install_editor}" == "true" ]]; then
    export fai_editor_install=1
  fi

  local install_editor_name=
  install_editor_name=$(_jq "${yaml_file}" .profiles.editor.name)
  if [ -n "${install_editor_name}" ]; then
    export fai_editor_name=${install_editor_name}
  fi

  local install_editor_host=
  install_editor_host=$(_jq "${yaml_file}" .profiles.editor.host)
  if [ -n "${install_editor_host}" ]; then
    export fai_editor_host=${install_editor_host}
  fi

  local install_editor_port=
  install_editor_port=$(_jq "${yaml_file}" .profiles.editor.port)
  if [ -n "${install_editor_port}" ]; then
    export fai_editor_port=${install_editor_port}
  fi

  local install_editor_shutdown=
  install_editor_shutdown=$(_jq "${yaml_file}" .profiles.editor.shutdown)
  if [ -n "${install_editor_shutdown}" ]; then
    export fai_editor_shutdown=${install_editor_shutdown}
  fi

  local install_editor_redirect=
  install_editor_redirect=$(_jq "${yaml_file}" .profiles.editor.redirect)
  if [ -n "${install_editor_redirect}" ]; then
    export fai_editor_redirect=${install_editor_redirect}
  fi

  local install_editor_ear=
  install_editor_ear=$(_jq "${yaml_file}" .profiles.editor.ear)
  if [ -n "${install_editor_ear}" ]; then
    export fai_editor_ear=${install_editor_ear}
  fi

  local install_editor_deploy_white_list=
  install_editor_deploy_white_list=$(
    _jq "${yaml_file}" .profiles.editor.deploy_white_list)
  if [ -n "${install_editor_deploy_white_list}" ]; then
    export fai_editor_deploy_white_list=${install_editor_deploy_white_list}
  fi
}

_parse_yaml_conf_file_environment() {
  local yaml_file=$1

  local configured_java_home=
  configured_java_home=$(_jq "${yaml_file}" .environment.java_home)
  if [[ -n "${configured_java_home}" ]]; then
    export java_home=${configured_java_home}
  fi

  local configured_java_oracle_licence_accepted=
  configured_java_oracle_licence_accepted=$(
    _jq "${yaml_file}" .environment.java_oracle_licence_accepted)
  if [[ "${configured_java_oracle_licence_accepted}" == "yes" ||
          "${configured_java_oracle_licence_accepted}" == "true" ]]; then
    export fai_java_oracle_licence_accepted=1
  fi

  local configured_java_download_url=
  configured_java_download_url=$(_jq "${yaml_file}" .environment.java_download_url)
  if [[ -n "${configured_java_download_url}" ]]; then
    export fai_java_download_url=${configured_java_download_url}
  fi

  local configured_environment=
  configured_environment=$(_jq "${yaml_file}" .environment.type)
  if [[ -n "${configured_environment}" ]]; then
    export fai_environment=${configured_environment}
  fi

  local configured_apt_pool=
  configured_apt_pool=$(_jq "${yaml_file}" .environment.apt.escenic.pool)
  if [[ -n "${configured_apt_pool}" ]]; then
    export fai_apt_vizrt_pool=${configured_apt_pool}
  fi

  local configured_deb_not_apt=
  configured_deb_not_apt=$(_jq "${yaml_file}" .environment.deb.escenic.use_deb_not_apt)
  if [[ "${configured_deb_not_apt}" == "yes" ||
          "${configured_deb_not_apt}" == "true" ]]; then
    export fai_package_deb_not_apt=1
  fi

  local configured_rpm_base_url=
  configured_rpm_base_url=$(_jq "${yaml_file}" .environment.rpm.escenic.base_url)
  if [[ -n "${configured_rpm_base_url}" ]]; then
    export fai_package_rpm_base_url=${configured_rpm_base_url}
  fi

  local configured_deb_base_url=
  configured_deb_base_url=$(_jq "${yaml_file}" .environment.deb.escenic.base_url)
  if [[ -n "${configured_deb_base_url}" ]]; then
    export fai_package_deb_base_url=${configured_deb_base_url}
  fi

  local skip_password_checks=
  skip_password_checks=$(
    _jq "${yaml_file}" .environment.skip_password_checks)
  if [[ "${skip_password_checks}" == "yes" ||
          "${skip_password_checks}" == "true" ]]; then
    export fai_skip_password_checks=1
  fi

  local count=0
  count=$(_jq "${yaml_file}" ".environment.maven.repositories | length")
  for ((i = 0; i < count; i++)); do
    local maven_repo=
    maven_repo=$(_jq "${yaml_file}" .environment.maven.repositories["${i}"])
    if [ -n "${fai_maven_repositories}" ]; then
      export fai_maven_repositories=${fai_maven_repositories}" "${maven_repo}
    else
      export fai_maven_repositories=${maven_repo}
    fi
  done

  local configured_conf_url=
  configured_conf_url=$(_jq "${yaml_file}" .environment.conf_url)
  if [ -n "${configured_conf_url}" ]; then
    export fai_conf_url=${configured_conf_url}
  fi
}

_parse_yaml_conf_file_monitoring() {
  local yaml_file=$1

  local install_monitoring=
  install_monitoring=$(_jq "${yaml_file}" .profiles.monitoring.install)
  if [[ "${install_monitoring}" == "yes" ||
          "${install_monitoring}" == "true" ]]; then
    export fai_monitoring_install=1
  fi
}

_parse_yaml_conf_file_assembly_tool() {
  local yaml_file=$1

  local install_assembly_tool=
  install_assembly_tool=$(_jq "${yaml_file}" .profiles.assembly_tool.install)
  if [[ "${install_assembly_tool}" == "yes" ||
          "${install_assembly_tool}" == "true" ]]; then
    export fai_assembly_tool_install=1
  fi
}

_parse_yaml_conf_file_nfs_server() {
  local yaml_file=$1

  local install_nfs=
  install_server_nfs=$(_jq "${yaml_file}" .profiles.nfs_server.install)
  if [[ "${install_server_nfs}" == "yes" ||
          "${install_server_nfs}" == "true" ]]; then
    export fai_nfs_server_install=1
  fi

  local nfs_server_address=
  nfs_server_address=$(_jq "${yaml_file}" .profiles.nfs_server.server_address)
  if [ -n "${nfs_server_address}" ]; then
    export fai_nfs_server_address=${nfs_server_address}
  fi

  local nfs_allowed_client_network=
  nfs_allowed_client_network=$(_jq "${yaml_file}" .profiles.nfs_server.allowed_client_network)
  if [ -n "${nfs_allowed_client_network}" ]; then
    export fai_nfs_allowed_client_network=${nfs_allowed_client_network}
  fi

  local nfs_client_mount_point_parent=
  nfs_client_mount_point_parent=$(_jq "${yaml_file}" .profiles.nfs_server.client_mount_point_parent)
  if [ -n "${nfs_client_mount_point_parent}" ]; then
    export fai_nfs_client_mount_point_parent=${nfs_client_mount_point_parent}
  fi

  local nfs_export_list=
  nfs_export_list=$(_jq "${yaml_file}" .profiles.nfs_server.export_list)
  if [ -n "${nfs_export_list}" ]; then
    export fai_nfs_export_list=${nfs_export_list}
  fi
}

_parse_yaml_conf_file_nfs_client() {
  local yaml_file=$1

  local install_client_nfs=
  install_client_nfs=$(_jq "${yaml_file}" .profiles.nfs_client.install)
  if [[ "${install_client_nfs}" == "yes" ||
          "${install_client_nfs}" == "true" ]]; then
    export fai_nfs_client_install=1
  fi

  local nfs_server_address=
  nfs_server_address=$(_jq "${yaml_file}" .profiles.nfs_client.server_address)
  if [ -n "${nfs_server_address}" ]; then
    export fai_nfs_server_address=${nfs_server_address}
  fi

  local nfs_allowed_client_network=
  nfs_allowed_client_network=$(_jq "${yaml_file}" .profiles.nfs_client.allowed_client_network)
  if [ -n "${nfs_allowed_client_network}" ]; then
    export fai_nfs_allowed_client_network=${nfs_allowed_client_network}
  fi

  local nfs_client_mount_point_parent=
  nfs_client_mount_point_parent=$(_jq "${yaml_file}" .profiles.nfs_client.client_mount_point_parent)
  if [ -n "${nfs_client_mount_point_parent}" ]; then
    export fai_nfs_client_mount_point_parent=${nfs_client_mount_point_parent}
  fi

  local nfs_export_list=
  nfs_export_list=$(_jq "${yaml_file}" .profiles.nfs_client.export_list)
  if [ -n "${nfs_export_list}" ]; then
    export fai_nfs_export_list=${nfs_export_list}
  fi
}

_parse_yaml_conf_file_presentation() {
  local yaml_file=$1

  local install_presentation=no
  install_presentation=$(_jq "${yaml_file}" .profiles.presentation.install)
  if [[ "${install_presentation}" == "yes" ||
          "${install_presentation}" == "true" ]]; then
    export fai_presentation_install=1
  fi

  local install_presentation_name=
  install_presentation_name=$(_jq "${yaml_file}" .profiles.presentation.name)
  if [ -n "${install_presentation_name}" ]; then
    export fai_presentation_name=${install_presentation_name}
  fi

  local install_presentation_host=
  install_presentation_host=$(_jq "${yaml_file}" .profiles.presentation.host)
  if [ -n "${install_presentation_host}" ]; then
    export fai_presentation_host=${install_presentation_host}
  fi

  local install_presentation_port=
  install_presentation_port=$(_jq "${yaml_file}" .profiles.presentation.port)
  if [ -n "${install_presentation_port}" ]; then
    export fai_presentation_port=${install_presentation_port}
  fi

  local install_presentation_shutdown=
  install_presentation_shutdown=$(_jq "${yaml_file}" .profiles.presentation.shutdown)
  if [ -n "${install_presentation_shutdown}" ]; then
    export fai_presentation_shutdown=${install_presentation_shutdown}
  fi

  local install_presentation_redirect=
  install_presentation_redirect=$(
    _jq "${yaml_file}" .profiles.presentation.redirect)
  if [ -n "${install_presentation_redirect}" ]; then
    export fai_presentation_redirect=${install_presentation_redirect}
  fi

  local install_presentation_ear=
  install_presentation_ear=$(_jq "${yaml_file}" .profiles.presentation.ear)
  if [ -n "${install_presentation_ear}" ]; then
    export fai_presentation_ear=${install_presentation_ear}
  fi

  local install_presentation_environment=
  install_presentation_environment=$(
    _jq "${yaml_file}" .profiles.presentation.environment)
  if [ -n "${install_presentation_environment}" ]; then
    export fai_presentation_environment=${install_presentation_environment}
  fi

  local install_presentation_deploy_white_list=
  install_presentation_deploy_white_list=$(
    _jq "${yaml_file}" .profiles.presentation.deploy_white_list)
  if [ -n "${install_presentation_deploy_white_list}" ]; then
    export fai_presentation_deploy_white_list=${install_presentation_deploy_white_list}
  fi

  local install_presentation_search_indexer_ws_uri=
  install_presentation_search_indexer_ws_uri=$(
    _jq "${yaml_file}" .profiles.presentation.search_indexer_ws_uri)
  if [ -n "${install_presentation_search_indexer_ws_uri}" ]; then
    export fai_presentation_search_indexer_ws_uri=${install_presentation_search_indexer_ws_uri}
  fi
}

_parse_yaml_conf_file_search() {
  local yaml_file=$1

  local install_search=no
  install_search=$(_jq "${yaml_file}" .profiles.search.install)
  if [[ "${install_search}" == "yes" ||
          "${install_search}" == "true" ]]; then
    export fai_search_install=1
  fi

  local search_legacy=no
  search_legacy=$(_jq "${yaml_file}" .profiles.search.legacy)
  if [[ "${search_legacy}" == "yes" ||
          "${search_legacy}" == "true" ]]; then
    export fai_search_legacy=1
  fi

  local search_for_editor=no
  search_for_editor=$(_jq "${yaml_file}" .profiles.search.for_editor)
  if [[ "${search_for_editor}" == "yes" ||
          "${search_for_editor}" == "true" ]]; then
    export fai_search_for_editor=1
  fi

  local install_search_name=
  install_search_name=$(_jq "${yaml_file}" .profiles.search.name)
  if [ -n "${install_search_name}" ]; then
    export fai_search_name=${install_search_name}
  fi

  local install_search_ear=
  install_search_ear=$(_jq "${yaml_file}" .profiles.search.ear)
  if [ -n "${install_search_ear}" ]; then
    export fai_search_ear=${install_search_ear}
  fi

  local install_search_host=
  install_search_host=$(_jq "${yaml_file}" .profiles.search.host)
  if [ -n "${install_search_host}" ]; then
    export fai_search_host=${install_search_host}
  fi

  local install_search_port=
  install_search_port=$(_jq "${yaml_file}" .profiles.search.port)
  if [ -n "${install_search_port}" ]; then
    export fai_search_port=${install_search_port}
  fi

  local install_search_shutdown=
  install_search_shutdown=$(_jq "${yaml_file}" .profiles.search.shutdown)
  if [ -n "${install_search_shutdown}" ]; then
    export fai_search_shutdown=${install_search_shutdown}
  fi

  local install_search_redirect=
  install_search_redirect=$(_jq "${yaml_file}" .profiles.search.redirect)
  if [ -n "${install_search_redirect}" ]; then
    export fai_search_redirect=${install_search_redirect}
  fi

  local install_search_indexer_ws_uri=
  install_search_indexer_ws_uri=$(_jq "${yaml_file}" .profiles.search.indexer_ws_uri)
  if [ -n "${install_search_indexer_ws_uri}" ]; then
    export fai_search_indexer_ws_uri=${install_search_indexer_ws_uri}
  fi
}

_parse_yaml_conf_file_cache() {
  local yaml_file=$1

  local install_cache=no
  install_cache=$(_jq "${yaml_file}" .profiles.cache.install)
  if [[ "${install_cache}" == "yes" ||
          "${install_cache}" == "true" ]]; then
    export fai_cache_install=1
  fi

  local install_cache_port=
  install_cache_port=$(_jq "${yaml_file}" .profiles.cache.port)
  if [ -n "${install_cache_port}" ]; then
    export fai_cache_port=${install_cache_port}
  fi

  local install_cache_conf_dir=
  install_cache_conf_dir=$(_jq "${yaml_file}" .profiles.cache.conf_dir)
  if [ -n "${install_cache_conf_dir}" ]; then
    export fai_cache_conf_dir=${install_cache_conf_dir}
  fi

  local count=0
  count=$(_jq "${yaml_file}" ".profiles.cache.backends | length")
  for ((i = 0; i < count; i++)); do
    local cache_backend=
    cache_backend=$(_jq "${yaml_file}" .profiles.cache.backends["${i}"])
    if [ -n "${fai_cache_backends}" ]; then
      export fai_cache_backends=${fai_cache_backends}" "${cache_backend}
    else
      export fai_cache_backends=${cache_backend}
    fi
  done
}

_parse_yaml_conf_file_analysis() {
  local yaml_file=$1

  local install_analysis=no
  install_analysis=$(_jq "${yaml_file}" .profiles.analysis.install)
  if [[ "${install_analysis}" == "yes" ||
          "${install_analysis}" == "true" ]]; then
    export fai_analysis_install=1
  fi

  local install_analysis_name=
  install_analysis_name=$(_jq "${yaml_file}" .profiles.analysis.name)
  if [ -n "${install_analysis_name}" ]; then
    export fai_analysis_name=${install_analysis_name}
  fi

  local install_analysis_host=
  install_analysis_host=$(_jq "${yaml_file}" .profiles.analysis.host)
  if [ -n "${install_analysis_host}" ]; then
    export fai_analysis_host=${install_analysis_host}
  fi

  local install_analysis_port=
  install_analysis_port=$(_jq "${yaml_file}" .profiles.analysis.port)
  if [ -n "${install_analysis_port}" ]; then
    export fai_analysis_port=${install_analysis_port}
  fi

  local install_analysis_shutdown=
  install_analysis_shutdown=$(_jq "${yaml_file}" .profiles.analysis.shutdown)
  if [ -n "${install_analysis_shutdown}" ]; then
    export fai_analysis_shutdown=${install_analysis_shutdown}
  fi

  local install_analysis_redirect=
  install_analysis_redirect=$(_jq "${yaml_file}" .profiles.analysis.redirect)
  if [ -n "${install_analysis_redirect}" ]; then
    export fai_analysis_redirect=${install_analysis_redirect}
  fi
}

_parse_yaml_conf_file_restore() {
  local yaml_file=$1

  local pre_wipe_solr=no
  pre_wipe_solr=$(_jq "${yaml_file}" .profiles.restore.pre_wipe_solr)
  if [[ "${pre_wipe_solr}" == "yes" ||
          "${pre_wipe_solr}" == "true" ]]; then
    export fai_restore_pre_wipe_solr=1
  fi
  local pre_wipe_logs=no
  pre_wipe_logs=$(_jq "${yaml_file}" .profiles.restore.pre_wipe_logs)
  if [[ "${pre_wipe_logs}" == "yes" ||
          "${pre_wipe_logs}" == "true" ]]; then
    export fai_restore_pre_wipe_logs=1
  fi
  local pre_wipe_cache=no
  pre_wipe_cache=$(_jq "${yaml_file}" .profiles.restore.pre_wipe_cache)
  if [[ "${pre_wipe_cache}" == "yes" ||
          "${pre_wipe_cache}" == "true" ]]; then
    export fai_restore_pre_wipe_cache=1
  fi

  local pre_wipe_crash=no
  pre_wipe_crash=$(_jq "${yaml_file}" .profiles.restore.pre_wipe_crash)
  if [[ "${pre_wipe_crash}" == "yes" ||
          "${pre_wipe_crash}" == "true" ]]; then
    export fai_restore_pre_wipe_crash=1
  fi

  local pre_wipe_all=no
  pre_wipe_all=$(_jq "${yaml_file}" .profiles.restore.pre_wipe_all)
  if [[ "${pre_wipe_all}" == "yes" ||
          "${pre_wipe_all}" == "true" ]]; then
    export fai_restore_pre_wipe_all=1
  fi

  local from_backup=no
  from_backup=$(_jq "${yaml_file}" .profiles.restore.from_backup)
  if [[ "${from_backup}" == "yes" ||
          "${from_backup}" == "true" ]]; then
    export fai_restore_from_backup=1
  fi

  local data_files=no
  data_files=$(_jq "${yaml_file}" .profiles.restore.data_files)
  if [[ "${data_files}" == "yes" ||
          "${data_files}" == "true" ]]; then
    export fai_restore_data_files=1
  fi

  local data_db=no
  data_db=$(_jq "${yaml_file}" .profiles.restore.db)
  if [[ "${data_db}" == "yes" ||
          "${data_db}" == "true" ]]; then
    export fai_restore_db=1
  fi

  local software_binaries=no
  software_binaries=$(
    _jq "${yaml_file}" .profiles.restore.software_binaries)
  if [[ "${software_binaries}" == "yes" ||
          "${software_binaries}" == "true" ]]; then
    export fai_restore_software_binaries=1
  fi

  local configuration=no
  configuration=$(
    _jq "${yaml_file}" .profiles.restore.configuration)
  if [[ "${configuration}" == "yes" ||
          "${configuration}" == "true" ]]; then
    export fai_restore_configuration=1
  fi

  local from_file=
  from_file=$(_jq "${yaml_file}" .profiles.restore.from_file)
  if [ -n "${from_file}" ]; then
    export fai_restore_from_file=${from_file}
  fi

}

_parse_yaml_conf_file_db() {
  local yaml_file=$1

  local install_db=no
  install_db=$(_jq "${yaml_file}" .profiles.db.install)
  if [[ "${install_db}" == "yes" ||
          "${install_db}" == "true" ]]; then
    export fai_db_install=1
  fi

  local db_master=no
  db_master=$(_jq "${yaml_file}" .profiles.db.master)
  if [[ "${db_master}" == "yes" ||
          "${db_master}" == "true" ]]; then
    export fai_db_master=1
  fi

  local db_drop_old_db_first=no
  db_drop_old_db_first=$(_jq "${yaml_file}" .profiles.db.drop_old_db_first)
  if [[ "${db_drop_old_db_first}" == "yes" ||
          "${db_drop_old_db_first}" == "true" ]]; then
    export fai_db_drop_old_db_first=1
  fi

  local db_replication=no
  db_replication=$(_jq "${yaml_file}" .profiles.db.replication)
  if [[ "${db_replication}" == "yes" ||
          "${db_replication}" == "true" ]]; then
    export fai_db_replication=1
  fi

  local install_db_user=
  install_db_user=$(_jq "${yaml_file}" .profiles.db.user)
  if [ -n "${install_db_user}" ]; then
    export fai_db_user=${install_db_user}
  fi

  local install_db_password=
  install_db_password=$(_jq "${yaml_file}" .profiles.db.password)
  if [ -n "${install_db_password}" ]; then
    export fai_db_password=${install_db_password}
  fi

  local install_db_schema=
  install_db_schema=$(_jq "${yaml_file}" .profiles.db.schema)
  if [ -n "${install_db_schema}" ]; then
    export fai_db_schema=${install_db_schema}
  fi

  local install_db_host=
  install_db_host=$(_jq "${yaml_file}" .profiles.db.host)
  if [ -n "${install_db_host}" ]; then
    export fai_db_host=${install_db_host}
  fi

  local install_db_port=
  install_db_port=$(_jq "${yaml_file}" .profiles.db.port)
  if [ -n "${install_db_port}" ]; then
    export fai_db_port=${install_db_port}
  fi

  local install_db_ear=
  install_db_ear=$(_jq "${yaml_file}" .profiles.db.ear)
  if [ -n "${install_db_ear}" ]; then
    export fai_db_ear=${install_db_ear}
  fi

  local install_db_vendor=
  install_db_vendor=$(_jq "${yaml_file}" .profiles.db.vendor)
  if [ -n "${install_db_vendor}" ]; then
    export db_vendor=${install_db_vendor}
  fi
}

_parse_yaml_conf_file_analysis_db() {
  local yaml_file=$1

  local install_db=no
  install_analysis_db=$(_jq "${yaml_file}" .profiles.analysis_db.install)
  if [[ "${install_analysis_db}" == "yes" ||
          "${install_analysis_db}" == "true" ]]; then
    export fai_analysis_db_install=1
  fi

  local install_analysis_db_user=
  install_analysis_db_user=$(_jq "${yaml_file}" .profiles.analysis_db.user)
  if [ -n "${install_analysis_db_user}" ]; then
    export fai_analysis_db_user=${install_analysis_db_user}
  fi

  local install_analysis_db_password=
  install_analysis_db_password=$(_jq "${yaml_file}" .profiles.analysis_db.password)
  if [ -n "${install_analysis_db_password}" ]; then
    export fai_analysis_db_password=${install_analysis_db_password}
  fi

  local install_analysis_db_schema=
  install_analysis_db_schema=$(_jq "${yaml_file}" .profiles.analysis_db.schema)
  if [ -n "${install_analysis_db_schema}" ]; then
    export fai_analysis_db_schema=${install_analysis_db_schema}
  fi

  local install_analysis_db_host=
  install_analysis_db_host=$(_jq "${yaml_file}" .profiles.analysis_db.host)
  if [ -n "${install_analysis_db_host}" ]; then
    export fai_analysis_db_host=${install_analysis_db_host}
  fi

  local install_analysis_db_port=
  install_analysis_db_port=$(_jq "${yaml_file}" .profiles.analysis_db.port)
  if [ -n "${install_analysis_db_port}" ]; then
    export fai_analysis_db_port=${install_analysis_db_port}
  fi
}

_parse_yaml_conf_file_cue() {
  local yaml_file=$1

  local install_cue=no
  install_cue=$(_jq "${yaml_file}" .profiles.cue.install)
  if [[ "${install_cue}" == "yes" ||
          "${install_cue}" == "true" ]]; then
    export fai_cue_install=1
  fi

  local install_cue_backend_ece=
  install_cue_backend_ece=$(_jq "${yaml_file}" .profiles.cue.backend_ece)
  if [ -n "${install_cue_backend_ece}" ]; then
    export fai_cue_backend_ece=${install_cue_backend_ece}
  fi

  local install_cue_backend_ng=
  install_cue_backend_ng=$(_jq "${yaml_file}" .profiles.cue.backend_ng)
  if [ -n "${install_cue_backend_ng}" ]; then
    export fai_cue_backend_ng=${install_cue_backend_ng}
  fi

  local count=0
  count=$(_jq "${yaml_file}" ".profiles.cue.cors_origins | length")
  for ((i = 0; i < count; i++)); do
    local cors_origin=
    cors_origin=$(_jq "${yaml_file}" .profiles.cue.cors_origins["${i}"])
    if [ -n "${fai_cue_cors_origins}" ]; then
      export fai_cue_cors_origins=${fai_cue_cors_origins}" "${cors_origin}
    else
      export fai_cue_cors_origins=${cors_origin}
    fi
  done
}

_jq() {
  local yaml_file=$1
  local key=$2

  local json=
  json=$(json_xs < "${yaml_file}" -f yaml -t json)
  jq --raw-output --exit-status <<< "${json}" "${key}" 2>/dev/null |
    grep -v null
}
