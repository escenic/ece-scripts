#! /usr/bin/env bash
## author: torstein@escenic.com

test_can_parse_yaml_conf_environment() {
  local yaml_file=
  yaml_file=$(mktemp)
  local foo_java_home=/usr/lib/jvm/foo-java-sdk
  local environment_type=production
  local foo_java_download_url=http://example.com/java-1.8.tar.gz
  local skip_password_checks=1
  local apt_pool=testing
  local mvn_repo1=repo1.example.com
  local mvn_repo2=repo2.example.com
  local conf_url=http://build.example.com/machine-conf-1.2.3.deb
  local rpm_base_url=http://unstable.yum.escenic.com/rpm
  local deb_base_url=http://unstable.apt.escenic.com
  local deb_not_apt=1

  cat > "${yaml_file}" <<EOF
---
environment:
  type: ${environment_type}
  java_home: ${foo_java_home}
  java_download_url: ${foo_java_download_url}
  java_oracle_licence_accepted: true
  skip_password_checks: true
  conf_url: ${conf_url}
  apt:
    escenic:
      pool: ${apt_pool}
  deb:
    escenic:
      use_deb_not_apt: true
      base_url: ${deb_base_url}
  rpm:
    escenic:
      base_url: ${rpm_base_url}

  maven:
    repositories:
      - ${mvn_repo1}
      - ${mvn_repo2}
EOF

  unset java_home
  unset fai_environment
  unset fai_java_download_url
  unset fai_java_oracle_licence_accepted
  unset fai_maven_repositories
  unset fai_conf_url
  unset fai_package_rpm_base_url
  unset fai_package_deb_not_apt

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertNotNull "Should set java_home" "${java_home}"
  assertEquals "Should set java_home" "${foo_java_home}" "${java_home}"
  assertEquals "Should set fai_java_download_url" \
               "${foo_java_download_url}" \
               "${fai_java_download_url}"
  assertEquals "Should set fai_java_oracle_licence_accepted" \
               1 \
               "${fai_java_oracle_licence_accepted}"
  assertEquals "Should set fai_environment (type)" \
               "${environment_type}" \
               "${fai_environment}"
  assertEquals "Should set fai_apt_vizrt_pool" \
               "${apt_pool}" \
               "${fai_apt_vizrt_pool}"
  assertEquals "Should set fai_skip_password_checks" \
               "${skip_password_checks}" \
               "${fai_skip_password_checks}"
  assertEquals "Should set fai_maven_repositories" \
               "${mvn_repo1} ${mvn_repo2}" \
               "${fai_maven_repositories}"
  assertEquals "Should set fai_conf_url" "${conf_url}" "${fai_conf_url}"
  assertEquals "Should set fai_package_rpm_base_url" \
               "${rpm_base_url}" \
               "${fai_package_rpm_base_url}"
  assertEquals "Should set fai_package_deb_base_url" \
               "${deb_base_url}" \
               "${fai_package_deb_base_url}"
  assertEquals "Should set fai_package_deb_not_apt" \
               "${deb_not_apt}" \
               "${fai_package_deb_not_apt}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_editor() {
  local editor_port=8000
  local editor_shutdown=5000
  local editor_redirect=4333
  local editor_name=fooeditor1
  local editor_host=edapp1
  local editor_ear=http://builder/engine.ear
  local editor_deploy_white_list=foo

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  editor:
    install: yes
    port: ${editor_port}
    host: ${editor_host}
    name: ${editor_name}
    redirect: ${editor_redirect}
    shutdown: ${editor_shutdown}
    ear: ${editor_ear}
    deploy_white_list: ${editor_deploy_white_list}
EOF

  unset fai_editor_install
  unset fai_editor_port
  unset fai_editor_shutdown
  unset fai_editor_redirect
  unset fai_editor_name
  unset fai_editor_ear
  unset fai_editor_deploy_white_list

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_editor_install" "${fai_editor_install}"
  assertEquals "Should set fai_editor_install" 1 "${fai_editor_install}"
  assertEquals "Should set fai_editor_port" "${editor_port}" "${fai_editor_port}"
  assertEquals "Should set fai_editor_host" "${editor_host}" "${fai_editor_host}"
  assertEquals "Should set fai_editor_shutdown" "${editor_shutdown}" "${fai_editor_shutdown}"
  assertEquals "Should set fai_editor_redirect" "${editor_redirect}" "${fai_editor_redirect}"
  assertEquals "Should set fai_editor_name" "${editor_name}" "${fai_editor_name}"
  assertEquals "Should set fai_editor_ear" "${editor_ear}" "${fai_editor_ear}"
  assertEquals "Should set fai_editor_deploy_white_list" \
               "${editor_deploy_white_list}" \
               "${fai_editor_deploy_white_list}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_presentation() {
  local presentation_port=8000
  local presentation_shutdown=5000
  local presentation_redirect=4333
  local presentation_name=presentation1
  local presentation_host=presapp1
  local presentation_ear=http://builder/engine.ear
  local presentation_environment=testing
  local presentation_deploy_white_list=foo
  local presentation_search_indexer_ws_uri=http://engine1/indexer-webservice/index/

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  presentation:
    install: yes
    ear: ${presentation_ear}
    environment: ${presentation_environment}
    host: ${presentation_host}
    name: ${presentation_name}
    port: ${presentation_port}
    redirect: ${presentation_redirect}
    shutdown: ${presentation_shutdown}
    deploy_white_list: ${presentation_deploy_white_list}
    search_indexer_ws_uri: ${presentation_search_indexer_ws_uri}
EOF

  unset fai_presentation_ear
  unset fai_presentation_environment
  unset fai_presentation_install
  unset fai_presentation_name
  unset fai_presentation_port
  unset fai_presentation_redirect
  unset fai_presentation_shutdown
  unset fai_presentation_deploy_white_list
  unset fai_presentation_search_indexer_ws_uri

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_presentation_install" "${fai_presentation_install}"
  assertEquals "Should set fai_presentation_install" 1 "${fai_presentation_install}"
  assertEquals "Should set fai_presentation_ear" "${presentation_ear}" "${fai_presentation_ear}"
  assertEquals "Should set fai_presentation_environment" \
               "${presentation_environment}" \
               "${fai_presentation_environment}"
  assertEquals "Should set fai_presentation_host" \
               "${presentation_host}" \
               "${fai_presentation_host}"
  assertEquals "Should set fai_presentation_name" \
               "${presentation_name}" \
               "${fai_presentation_name}"
  assertEquals "Should set fai_presentation_port" \
               "${presentation_port}" \
               "${fai_presentation_port}"
  assertEquals "Should set fai_presentation_redirect" \
               "${presentation_redirect}" \
               "${fai_presentation_redirect}"
  assertEquals "Should set fai_presentation_shutdown" \
               "${presentation_shutdown}" \
               "${fai_presentation_shutdown}"
  assertEquals "Should set fai_presentation_search_indexer_ws_uri" \
               "${presentation_search_indexer_ws_uri}" \
               "${fai_presentation_search_indexer_ws_uri}"
  assertEquals "Should set fai_presentation_deploy_white_list" \
               "${presentation_deploy_white_list}" \
               "${fai_presentation_deploy_white_list}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_search() {
  local search_port=8000
  local search_shutdown=5000
  local search_redirect=4333
  local search_name=search1
  local search_host=searchhost
  local search_legacy=1
  local search_for_editor=1
  local search_legacy=1
  local search_ear=http://builder/engine.ear
  local search_indexer_ws_uri=http://engine/indexer-webservice/index/

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  search:
    install: yes
    legacy: yes
    ear: ${search_ear}
    for_editor: true
    indexer_ws_uri: ${search_indexer_ws_uri}
    port: ${search_port}
    host: ${search_host}
    name: ${search_name}
    redirect: ${search_redirect}
    shutdown: ${search_shutdown}
EOF

  unset fai_search_install
  unset fai_search_host
  unset fai_search_port
  unset fai_search_shutdown
  unset fai_search_redirect
  unset fai_search_name
  unset fai_search_legacy
  unset fai_search_for_editor
  unset fai_search_ear
  unset fai_search_indexer_ws_uri

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_search_install" "${fai_search_install}"
  assertEquals "Should set fai_search_install" 1 "${fai_search_install}"

  assertEquals "Should set fai_search_host" "${search_host}" "${fai_search_host}"
  assertEquals "Should set fai_search_port" "${search_port}" "${fai_search_port}"
  assertEquals "Should set fai_search_shutdown" "${search_shutdown}" "${fai_search_shutdown}"
  assertEquals "Should set fai_search_redirect" "${search_redirect}" "${fai_search_redirect}"
  assertEquals "Should set fai_search_name" "${search_name}" "${fai_search_name}"
  assertEquals "Should set fai_search_legacy" "${search_legacy}" "${fai_search_legacy}"
  assertEquals "Should set fai_search_for_editor" "${search_for_editor}" "${fai_search_for_editor}"
  assertEquals "Should set fai_search_ear" "${search_ear}" "${fai_search_ear}"
  assertEquals "Should set fai_search_indexer_ws_uri" "${search_indexer_ws_uri}" "${fai_search_indexer_ws_uri}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_db() {
  local yaml_file=
  yaml_file=$(mktemp)
  local db_user=foodbuser
  local db_password=foodbpassword
  local db_schema=foodbdb
  local db_host=foodbhost
  local db_port=foodbport
  local db_install=yes
  local db_ear=db.ear
  local db_master=1
  local db_drop_old_db_first=1
  local db_replication=1
  local _db_vendor=foodb

  cat > "${yaml_file}" <<EOF
---
profiles:
  db:
    install: ${db_install}
    master: true
    user: ${db_user}
    ear: ${db_ear}
    password: ${db_password}
    schema: ${db_schema}
    host: ${db_host}
    port: ${db_port}
    drop_old_db_first: yes
    replication: yes
    vendor: ${_db_vendor}
EOF

  unset fai_db_install
  unset fai_db_master
  unset fai_db_user
  unset fai_db_password
  unset fai_db_schema
  unset fai_db_host
  unset fai_db_port
  unset fai_db_ear
  unset fai_db_drop_old_db_first
  unset fai_db_replication
  unset db_vendor

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertNotNull "Should set fai_db_install" "${fai_db_install}"
  assertEquals "Should set fai_db_install" 1 "${fai_db_install}"

  assertEquals "Should set fai_db_master" "${db_master}" "${fai_db_master}"

  assertEquals "Should set fai_db_drop_old_db_first" \
               "${db_drop_old_db_first}" \
               "${fai_db_drop_old_db_first}"

  assertEquals "Should set fai_db_replication" \
               "${db_replication}" \
               "${fai_db_replication}"

  assertNotNull "Should set fai_db_user" "${fai_db_user}"
  assertEquals "Should set fai_db_user" "${db_user}" "${fai_db_user}"

  assertNotNull "Should set fai_db_ear" "${fai_db_ear}"
  assertEquals "Should set fai_db_ear" "${db_ear}" "${fai_db_ear}"

  assertNotNull "Should set fai_db_password" "${fai_db_password}"
  assertEquals "Should set fai_db_password" "${db_password}" "${fai_db_password}"

  assertNotNull "Should set fai_db_schema" "${fai_db_schema}"
  assertEquals "Should set fai_db_schema" "${db_schema}" "${fai_db_schema}"

  assertNotNull "Should set fai_db_host" "${fai_db_host}"
  assertEquals "Should set fai_db_host" "${db_host}" "${fai_db_host}"

  assertNotNull "Should set fai_db_port" "${fai_db_port}"
  assertEquals "Should set fai_db_port" "${db_port}" "${fai_db_port}"

  assertNotNull "Should set db_vendor" "${db_vendor}"
  assertEquals "Should set db_vendor" "${_db_vendor}" "${db_vendor}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_cache() {
  local be1="app1"
  local be2="app2"
  local conf_dir=/opt/etc/varnish
  local port=81

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  cache:
    install: yes
    conf_dir: ${conf_dir}
    port: ${port}
    backends:
      - ${be1}
      - ${be2}
EOF

  unset fai_cache_install
  unset fai_cache_backends
  unset fai_cache_port
  unset fai_cache_conf_dir

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_cache_install" "${fai_cache_install}"
  assertEquals "Should set fai_cache_install" 1 "${fai_cache_install}"
  assertEquals "fai_cache_backends" "${be1} ${be2}" "${fai_cache_backends}"
  assertEquals "fai_cache_conf_dir" "${conf_dir}" "${fai_cache_conf_dir}"
  assertEquals "fai_cache_port" "${port}" "${fai_cache_port}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_cue() {
  local cue_backend_ece=http://ece.example.com
  local cue_backend_ece_local=http://localhost:8080
  local cue_backend_ng=http://ng.example.com
  local cue_backend_bridge=http://bridge.example.com
  local cue_cors_origin1=editor.example.com
  local cue_cors_origin2=cue.example.com

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  cue:
    install: yes
    backend_ece: ${cue_backend_ece}
    backend_ece_local: ${cue_backend_ece_local}
    backend_ng: ${cue_backend_ng}
    backend_bridge: ${cue_backend_bridge}
    cors_origins:
      - ${cue_cors_origin1}
      - ${cue_cors_origin2}
EOF

  unset fai_cue_install
  unset fai_cue_backend_ece
  unset fai_cue_backend_ece_local
  unset fai_cue_backend_ng
  unset fai_cue_backend_bridge
  unset fai_cue_cors_origins

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_cue_install" "${fai_cue_install}"
  assertEquals "Should set fai_cue_install" 1 "${fai_cue_install}"
  assertEquals "fai_cue_backend_ece" "${cue_backend_ece}" "${fai_cue_backend_ece}"
  assertEquals "fai_cue_backend_ece_local" "${cue_backend_ece_local}" "${fai_cue_backend_ece_local}"
  assertEquals "fai_cue_backend_ng" "${cue_backend_ng}" "${fai_cue_backend_ng}"
  assertEquals "fai_cue_backend_bridge" "${cue_backend_bridge}" "${fai_cue_backend_bridge}"
  assertEquals "fai_cue_cors_origins" "${cue_cors_origin1} ${cue_cors_origin2}" "${fai_cue_cors_origins}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_sse_proxy() {
  local exposed_port=80
  local exposed_host=proxy.example.com
  local sse_proxy_ece_port=8083
  local sse_proxy_ece_redirect=8443
  local sse_proxy_backend1_uri=http://foo
  local sse_proxy_backend1_user=foo
  local sse_proxy_backend1_password=p
  local sse_proxy_backend2_uri=http://bar
  local sse_proxy_backend2_user=bar
  local sse_proxy_backend2_password=b

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  sse_proxy:
    install: yes
    exposed_host: ${exposed_host}
    exposed_port: ${exposed_port}
    ece_port: ${sse_proxy_ece_port}
    ece_redirect: ${sse_proxy_ece_redirect}
    backends:
      - uri: ${sse_proxy_backend1_uri}
        user: ${sse_proxy_backend1_user}
        password: ${sse_proxy_backend1_password}
      - uri: ${sse_proxy_backend2_uri}
        user: ${sse_proxy_backend2_user}
        password: ${sse_proxy_backend2_password}
EOF

  unset fai_sse_proxy_backends
  unset fai_sse_proxy_ece_port
  unset fai_sse_proxy_ece_redirect
  unset fai_sse_proxy_exposed_host
  unset fai_sse_proxy_exposed_port
  unset fai_sse_proxy_install

  sse_proxy_backends="${sse_proxy_backend2_uri} ${sse_proxy_backend2_user} ${sse_proxy_backend2_password}
${sse_proxy_backend1_uri} ${sse_proxy_backend1_user} ${sse_proxy_backend1_password}
"

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_sse_install" "${fai_sse_proxy_install}"
  assertEquals "Should set fai_sse_proxy_install" 1 "${fai_sse_proxy_install}"
  assertEquals "Should set fai_sse_proxy_exposed_host" "${exposed_host}" "${fai_sse_proxy_exposed_host}"
  assertEquals "Should set fai_sse_proxy_exposed_port" "${exposed_port}" "${fai_sse_proxy_exposed_port}"
  assertEquals "Should set fai_sse_proxy_ece_port" "${sse_proxy_ece_port}" "${fai_sse_proxy_ece_port}"
  assertEquals "Should set fai_sse_proxy_ece_redirect" "${sse_proxy_ece_redirect}" "${fai_sse_proxy_ece_redirect}"
  assertEquals "Should set fai_sse_proxy_backends" "${sse_proxy_backends}" "${fai_sse_proxy_backends}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_nfs_server() {
  local nfs_server_address="nfs.example.com"
  local nfs_allowed_client_network="10.0.0.1/24"
  local nfs_export_list="/var/exports/app1 /var/exports/app2"
  local nfs_client_mount_point_parent=/mnt
  local port=81

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  nfs_server:
    install: yes
    server_address: ${nfs_server_address}
    allowed_client_network: ${nfs_allowed_client_network}
    export_list: ${nfs_export_list}
    client_mount_point_parent: ${nfs_client_mount_point_parent}
EOF

  unset fai_nfs_export_list
  unset fai_nfs_server_address
  unset fai_nfs_server_install
  unset fai_nfs_allowed_client_network
  unset fai_nfs_client_mount_point_parent

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_nfs_server_install" "${fai_nfs_server_install}"
  assertEquals "Should set fai_nfs_server_install" 1 "${fai_nfs_server_install}"
  assertEquals "fai_nfs_server_address" "${nfs_server_address}" "${fai_nfs_server_address}"
  assertEquals "fai_nfs_allowed_client_network" "${nfs_allowed_client_network}" "${fai_nfs_allowed_client_network}"
  assertEquals "fai_nfs_export_list" "${nfs_export_list}" "${fai_nfs_export_list}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_nfs_client() {
  local nfs_server_address="nfs.example.com"
  local nfs_allowed_client_network="10.0.0.1/24"
  local nfs_export_list="/var/exports/app1 /var/exports/app2"
  local nfs_client_mount_point_parent=/mnt
  local port=81

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  nfs_client:
    install: yes
    server_address: ${nfs_server_address}
    allowed_client_network: ${nfs_allowed_client_network}
    export_list: ${nfs_export_list}
    client_mount_point_parent: ${nfs_client_mount_point_parent}
EOF

  unset fai_nfs_export_list
  unset fai_nfs_server_address
  unset fai_nfs_client_install
  unset fai_nfs_allowed_client_network
  unset fai_nfs_client_mount_point_parent

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_nfs_client_install" "${fai_nfs_client_install}"
  assertEquals "Should set fai_nfs_client_install" 1 "${fai_nfs_client_install}"
  assertEquals "fai_nfs_server_address" "${nfs_server_address}" "${fai_nfs_server_address}"
  assertEquals "fai_nfs_allowed_client_network" "${nfs_allowed_client_network}" "${fai_nfs_allowed_client_network}"
  assertEquals "fai_nfs_export_list" "${nfs_export_list}" "${fai_nfs_export_list}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_assembly_tool() {
  local yaml_file=
  yaml_file=$(mktemp)
  local assembly_tool_install=1
  cat > "${yaml_file}" <<EOF
---
profiles:
  assembly_tool:
    install: yes
EOF

  unset fai_assembly_tool_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Wrong fai_assembly_tool_install" \
               "${assembly_tool_install}" \
               "${fai_assembly_tool_install}"
}

test_can_parse_yaml_conf_credentials() {
  local yaml_file=
  yaml_file=$(mktemp)
  local escenic_download_user=foouser
  local escenic_download_password=barpassword
  local builder_download_user=buildy
  local builder_download_password=boo
  local unstable_yum_user=once
  local unstable_yum_password=coming
  local unstable_apt_user=two
  local unstable_apt_password=twice

  cat > "${yaml_file}" <<EOF
---
credentials:
  - site: maven.escenic.com
    user: ${escenic_download_user}
    password: ${escenic_download_password}
  - site: builder
    user: ${builder_download_user}
    password: ${builder_download_password}
  - site: unstable.yum.escenic.com
    user: ${unstable_yum_user}
    password: ${unstable_yum_password}
  - site: unstable.apt.escenic.com
    user: ${unstable_apt_user}
    password: ${unstable_apt_password}
EOF

  unset technet_user
  unset technet_password
  unset fai_package_rpm_user
  unset fai_package_rpm_password
  unset fai_package_apt_user
  unset fai_package_apt_password
  unset fai_builder_http_user
  unset fai_builder_http_password
  unset fai_conf_builder_http_user
  unset fai_conf_builder_http_password

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set technet_user" "${technet_user}"
  assertEquals "Should set technet_user" "${escenic_download_user}" "${technet_user}"

  assertNotNull "Should set technet_password" "${technet_password}"
  assertEquals "Should set technet_password" "${escenic_download_password}" "${technet_password}"

  assertEquals "Should set fai_builder_http_user" \
               "${builder_download_user}" \
               "${fai_builder_http_user}"
  assertEquals "Should set fai_builder_http_password" \
               "${builder_download_password}" \
               "${fai_builder_http_password}"
  assertEquals "Should set fai_conf_builder_http_user" \
               "${builder_download_user}" \
               "${fai_conf_builder_http_user}"
  assertEquals "Should set fai_conf_builder_http_password" \
               "${builder_download_password}" \
               "${fai_conf_builder_http_password}"
  assertEquals "Should set fai_package_rpm_user" \
               "${unstable_yum_user}" \
               "${fai_package_rpm_user}"
  assertEquals "Should set fai_package_rpm_password" \
               "${unstable_yum_password}" \
               "${fai_package_rpm_password}"
  assertEquals "Should set fai_package_apt_user" \
               "${unstable_apt_user}" \
               "${fai_package_apt_user}"
  assertEquals "Should set fai_package_apt_password" \
               "${unstable_apt_password}" \
               "${fai_package_apt_password}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_credentials_stable_yum() {
  local yaml_file=
  yaml_file=$(mktemp)
  local stable_yum_user=always
  local stable_yum_password=there

  cat > "${yaml_file}" <<EOF
---
credentials:
  - site: yum.escenic.com
    user: ${stable_yum_user}
    password: ${stable_yum_password}
EOF

  unset fai_package_rpm_user
  unset fai_package_rpm_password

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Should set fai_package_rpm_user" \
               "${stable_yum_user}" \
               "${fai_package_rpm_user}"
  assertEquals "Should set fai_package_rpm_password" \
               "${stable_yum_password}" \
               "${fai_package_rpm_password}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_credentials_stable_apt() {
  local yaml_file=
  yaml_file=$(mktemp)
  local stable_apt_user=always
  local stable_apt_password=there

  cat > "${yaml_file}" <<EOF
---
credentials:
  - site: apt.escenic.com
    user: ${stable_apt_user}
    password: ${stable_apt_password}
EOF

  unset fai_package_apt_user
  unset fai_package_apt_password

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Should set fai_package_apt_user" \
               "${stable_apt_user}" \
               "${fai_package_apt_user}"
  assertEquals "Should set fai_package_apt_password" \
               "${stable_apt_password}" \
               "${fai_package_apt_password}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_create_publication() {
  local yaml_file=
  yaml_file=$(mktemp)
  local publication_ear=http://builder/engine.ear
  local publication_webapp1=pub.war
  local publication_webapp2=loc.war

  local publication1_name=foopub
  local publication1_update_app_server_conf=1
  local publication1_update_ece_conf=1
  local publication1_update_nursery_conf=1
  local publication1_name=foopub
  local publication1_name=foopub
  local publication1_remove_file1=stoo.pid
  local publication1_remove_file2=does.it
  local publication1_environment=testing
  local publication1_war=pub.war
  local publication1_domain=foo.example.com
  local publication1_alias1=fooalias1.example.com
  local publication1_alias2=fooalias2.example.com

  cat > "${yaml_file}" <<EOF
---
profiles:
   publications:
     - name: ${publication1_name}
       create: true
       update_app_server_conf: true
       update_ece_conf: true
       update_nursery_conf: true
       war: ${publication1_war}
       war_remove_list:
         - ${publication1_remove_file1}
         - ${publication1_remove_file2}
       webapps:
         - ${publication_webapp1}
         - ${publication_webapp2}
       domain: ${publication1_domain}
       ear: ${publication_ear}
       environment: ${publication1_environment}
       aliases:
         - ${publication1_alias1}
         - ${publication1_alias2}
EOF

  unset fai_publication_domain_mapping_list
  unset fai_publication_ear
  unset fai_publication_update_app_server_conf
  unset fai_publication_update_ece_conf
  unset fai_publication_update_nursery_conf
  unset fai_publication_war_remove_file_list
  unset fai_publication_environment
  unset fai_publication_webapps
  unset fai_publications_webapps # arg, the plural

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Having pubs defined, sets enabled flag" \
               1 \
               "${fai_publication_create}"
  assertEquals "fai_publication_ear should have been set" \
               "${publication_ear}" \
               "${fai_publication_ear}"
  assertEquals "fai_publication_update_app_server_conf should have been set" \
               "${publication1_update_app_server_conf}" \
               "${fai_publication_update_app_server_conf}"
  assertEquals "fai_publication_update_nursery_conf should have been set" \
               "${publication1_update_nursery_conf}" \
               "${fai_publication_update_nursery_conf}"
  assertEquals "fai_publication_update_ece_conf should have been set" \
               "${publication1_update_ece_conf}" \
               "${fai_publication_update_ece_conf}"
  assertEquals "fai_publication_webapps should have been set" \
               "${publication_webapp1} ${publication_webapp2}" \
               "${fai_publication_webapps}"
  assertEquals "fai_publications_webapps should have been set" \
               "${fai_publication_webapps}" \
               "${fai_publications_webapps}"
  assertEquals "fai_publication_environment should have been set" \
               "${publication1_environment}" \
               "${fai_publication_environment}"
  assertEquals "fai_publication_war_remove_file_list should have been set" \
               "${publication1_remove_file1} ${publication1_remove_file2}" \
               "${fai_publication_war_remove_file_list}"
  assertNotNull "Able to parse info for creating publications" \
                "${fai_publication_domain_mapping_list}"

  for el in ${fai_publication_domain_mapping_list}; do
    IFS='#' read -r publication domain aliases <<< "${el}"
    IFS=',' read -r name war <<< "$publication"
    assertEquals "publication name from map" \
                 "${publication1_name}" \
                 "${name}"
    assertEquals "publication war from map" \
                 "${publication1_war}" \
                 "${war}"
    assertEquals "publication domain from map" \
                 "${publication1_domain}" \
                 "${domain}"
    assertEquals "publication aliases from map" \
                 "${publication1_alias1},${publication1_alias2}" \
                 "${aliases}"
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_publication() {
  local yaml_file=
  yaml_file=$(mktemp)
  local publication1_name=foopub
  local publication1_war=pub.war
  local publication1_domain=foo.example.com
  local publication1_alias1=fooalias1.example.com
  local publication1_alias2=fooalias2.example.com
  local publication1_aliases=${publication1_alias1},${publication1_alias2}

  local publication2_name=barpub
  local publication2_war=bar.war
  local publication2_domain=bar.example.com
  local publication2_alias1=baralias1.example.com
  local publication2_alias2=baralias2.example.com
  local publication2_aliases=${publication2_alias1},${publication2_alias2}

  cat > "${yaml_file}" <<EOF
---
profiles:
   publications:
     - name: ${publication1_name}
       war: ${publication1_war}
       domain: ${publication1_domain}
       aliases:
         - ${publication1_alias1}
         - ${publication1_alias2}
     - name: ${publication2_name}
       war: ${publication2_war}
       domain: ${publication2_domain}
       aliases:
          - ${publication2_alias1}
          - ${publication2_alias2}
EOF

  unset fai_publication_domain_mapping_list
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Able to parse info for creating publications" \
                "${fai_publication_domain_mapping_list}"
  for el in ${fai_publication_domain_mapping_list}; do
    IFS='#' read -r publication domain aliases <<< "${el}"
    IFS=',' read -r name war <<< "$publication"

    if [[ "${name}" == "${publication1_name}" ]]; then
      found_publication1_name=1
    elif [[ "${name}" == "${publication2_name}" ]]; then
      found_publication2_name=1
    fi
    if [[ "${war}" == "${publication1_war}" ]]; then
      found_publication1_war=1
    elif [[ "${war}" == "${publication2_war}" ]]; then
      found_publication2_war=1
    fi
    if [[ "${domain}" == "${publication1_domain}" ]]; then
      found_publication1_domain=1
    elif [[ "${domain}" == "${publication2_domain}" ]]; then
      found_publication2_domain=1
    fi
    if [[ "${aliases}" == "${publication1_aliases}" ]]; then
      found_publication1_aliases=1
    elif [[ "${aliases}" == "${publication2_aliases}" ]]; then
      found_publication2_aliases=1
    fi
  done

  assertEquals "Can configure both pubs, name" 1 "${found_publication1_name}"
  assertEquals "Can configure both pubs, name" 1 "${found_publication2_name}"
  assertEquals "Can configure both pubs, war" 1 "${found_publication1_war}"
  assertEquals "Can configure both pubs, war" 1 "${found_publication2_war}"
  assertEquals "Can configure both pubs, domain" 1 "${found_publication1_domain}"
  assertEquals "Can configure both pubs, domain" 1 "${found_publication2_domain}"
  assertEquals "Can configure both pubs, aliases" 1 "${found_publication1_aliases}"
  assertEquals "Can configure both pubs, aliases" 1 "${found_publication2_aliases}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_packages() {
  local yaml_file=
  yaml_file=$(mktemp)
  local package_name=escenic-content-engine
  local package_version=6.1.0-2
  local package_arch=i386

  cat > "${yaml_file}" <<EOF
---
packages:
  - name: ${package_name}
    version: ${package_version}
    arch: ${package_arch}
EOF
  unset fai_package_map
  unset fai_package_arch_map
  declare -A fai_package_map
  declare -A fai_package_arch_map
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  for name in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${name}]}
    local arch=${fai_package_arch_map[${name}]}
    assertEquals "Should have parsed package name" "${package_name}" "${name}"
    assertEquals "Should have parsed package version" "${package_version}" "${version}"
    assertEquals "Should have parsed package version" "${package_arch}" "${arch}"
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_packages_multiple() {
  local yaml_file=
  yaml_file=$(mktemp)

  local package_name=escenic-content-engine
  local package_version=6.1.0-2
  local package_name_without_version=escenic-video

  cat > "${yaml_file}" <<EOF
---
packages:
  - name: ${package_name}
    version: ${package_version}
  - name: ${package_name_without_version}
EOF
  unset fai_package_map
  declare -A fai_package_map
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  for name in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${name}]}

    if [[ "${name}" == "${package_name_without_version}" ]]; then
      assertNull "Package without version should have no version" \
                 "${version}"
    else
      assertEquals "Should have parsed package version" \
                   "${package_version}" \
                   "${version}"
    fi
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_analysis() {
  local yaml_file=
  yaml_file=$(mktemp)

  local analysis_port=9000
  local analysis_name=stats1
  local analysis_shutdown=5553
  local analysis_redirect=4553
  local analysis_host=stats1

  cat > "${yaml_file}" <<EOF
---
profiles:
  analysis:
    install: yes
    name: ${analysis_name}
    port: ${analysis_port}
    host: ${analysis_host}
    shutdown: ${analysis_shutdown}
    redirect: ${analysis_redirect}
EOF

  unset fai_analysis_install
  unset fai_analysis_name
  unset fai_analysis_port
  unset fai_analysis_host
  unset fai_analysis_shutdown
  unset fai_analysis_redirect
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertNotNull "Should set fai_analysis_install" "${fai_analysis_install}"
  assertEquals "Should set fai_analysis_install" 1 "${fai_analysis_install}"
  assertEquals "Should set fai_analysis_name" "${analysis_name}" "${fai_analysis_name}"
  assertEquals "Should set fai_analysis_port" "${analysis_port}" "${fai_analysis_port}"
  assertEquals "Should set fai_analysis_host" "${analysis_host}" "${fai_analysis_host}"
  assertEquals "Should set fai_analysis_shutdown" "${analysis_shutdown}" "${fai_analysis_shutdown}"
  assertEquals "Should set fai_analysis_redirect" "${analysis_redirect}" "${fai_analysis_redirect}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_analysis_db() {
  local yaml_file=
  yaml_file=$(mktemp)

  local analysis_db_user=foouser
  local analysis_db_password=foopass
  local analysis_db_schema=fooanalysis_db

  cat > "${yaml_file}" <<EOF
---
profiles:
  analysis_db:
    install: yes
    user: ${analysis_db_user}
    password: ${analysis_db_password}
    schema: ${analysis_db_schema}
EOF

  unset fai_analysis_db_install
  unset fai_analysis_db_user
  unset fai_analysis_db_password
  unset fai_analysis_db_schema
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertNotNull "Should set fai_analysis_install" "${fai_analysis_install}"
  assertEquals "Should set fai_analysis_install" 1 "${fai_analysis_install}"
  assertEquals "Should set fai_analysis_db_user" "${analysis_db_user}" "${fai_analysis_db_user}"
  assertEquals "Should set fai_analysis_db_password" "${analysis_db_password}" "${fai_analysis_db_password}"
  assertEquals "Should set fai_analysis_db_schema" "${analysis_db_schema}" "${fai_analysis_db_schema}"

  rm -rf "${yaml_file}"
}

_test_can_parse_yaml_conf_use_escenic_packages() {
  local yaml_file=
  yaml_file=$(mktemp)
  local foo_java_home=/usr/lib/jvm/foo-java-sdk

  cat > "${yaml_file}" <<EOF
---
packages:
  foo: 1
EOF

  unset fai_package_enabled
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_package_enabled" "${fai_package_enabled}"
  assertEquals "Should set fai_package_enabled" 1 "${fai_package_enabled}"

  # no packages: block means don't use packages
  cat > "${yaml_file}" <<EOF
---
foo:
EOF

  unset fai_package_enabled
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNull "Should NOT set fai_package_enabled" "${fai_package_enabled}"
  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_restore() {
  local restore_pre_wipe_solr=1
  local restore_pre_wipe_all=1
  local restore_pre_wipe_logs=1
  local restore_pre_wipe_cache=1
  local restore_pre_wipe_crash=1
  local restore_from_backup=1
  local restore_data_files=1
  local restore_software_binaries=1
  local restore_db=1
  local restore_configuration=1
  local restore_from_file=/var/backups/backup.tar.gz

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  restore:
    pre_wipe_solr: true
    pre_wipe_all: true
    pre_wipe_logs: true
    pre_wipe_cache: true
    pre_wipe_crash: true
    from_backup: true
    data_files: true
    software_binaries: true
    db: true
    configuration: true
    from_file: ${restore_from_file}
EOF
  unset fai_restore_pre_wipe_solr
  unset fai_restore_pre_wipe_all
  unset fai_restore_pre_wipe_logs
  unset fai_restore_pre_wipe_cache
  unset fai_restore_pre_wipe_crash
  unset fai_restore_from_backup
  unset fai_restore_data_files
  unset fai_restore_software_binaries
  unset fai_restore_db
  unset fai_restore_configuration
  unset fai_restore_from_file
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertEquals "Wrong fai_restore_pre_wipe_solr" \
               "${restore_pre_wipe_solr}" \
               "${fai_restore_pre_wipe_solr}"
  assertEquals "Wrong fai_restore_pre_wipe_all" \
               "${restore_pre_wipe_all}" \
               "${fai_restore_pre_wipe_all}"
  assertEquals "Wrong fai_restore_pre_wipe_logs" \
               "${restore_pre_wipe_logs}" \
               "${fai_restore_pre_wipe_logs}"
  assertEquals "Wrong fai_restore_pre_wipe_cache" \
               "${restore_pre_wipe_cache}" \
               "${fai_restore_pre_wipe_cache}"
  assertEquals "Wrong fai_restore_pre_wipe_crash" \
               "${restore_pre_wipe_crash}" \
               "${fai_restore_pre_wipe_crash}"
  assertEquals "Wrong fai_restore_from_backup" \
               "${restore_from_backup}" \
               "${fai_restore_from_backup}"
  assertEquals "Wrong fai_restore_data_files" \
               "${restore_data_files}" \
               "${fai_restore_data_files}"
  assertEquals "Wrong fai_restore_software_binaries" \
               "${restore_software_binaries}" \
               "${fai_restore_software_binaries}"
  assertEquals "Wrong fai_restore_db" \
               "${restore_db}" \
               "${fai_restore_db}"
  assertEquals "Wrong fai_restore_configuration" \
               "${restore_configuration}" \
               "${fai_restore_configuration}"
  assertEquals "Wrong fai_restore_from_file" \
               "${restore_from_file}" \
               "${fai_restore_from_file}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_editor_install_multi_profiles() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  editor:
    install: yes
  search:
    install: yes
  db:
    install: no
EOF

  unset fai_editor_install
  unset fai_search_install
  unset fai_db_install

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_editor_install" "${fai_editor_install}"
  assertEquals "Should set fai_editor_install" 1 "${fai_editor_install}"
  assertEquals "Should set fai_search_install" 1 "${fai_search_install}"
  assertNull "Should not have set fai_db_install" "${fai_db_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_cache() {
  local cache_port=80
  local cache_conf_dir=/opt/etc/varnish
  local cache_be1=pres1
  local cache_be2=pres2

  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  cache:
    install: yes
    port: ${cache_port}
    conf_dir: ${cache_conf_dir}
    backends:
      - ${cache_be1}
      - ${cache_be2}
EOF

  unset fai_cache_install
  unset fai_cache_backends
  unset fai_cache_conf_dir
  unset fai_cache_port

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_cache_install" "${fai_cache_install}"
  assertEquals "Should set fai_cache_install" 1 "${fai_cache_install}"
  assertEquals "Should set fai_cache_backends" "${cache_be1} ${cache_be2}" "${fai_cache_backends}"
  assertEquals "Should set fai_cache_port" "${cache_port}" "${fai_cache_port}"
  assertEquals "Should set fai_cache_conf_dir" "${cache_conf_dir}" "${fai_cache_conf_dir}"
  rm -rf "${yaml_file}"
}

test_can_recognise_a_yaml_conf_file() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
foo: bar
EOF

  local expected=0
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

test_can_recognise_a_conf_file_thats_not_yaml_xml() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
<foo>bar</foo>
EOF

  local expected=1
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

test_can_recognise_a_conf_file_thats_not_yaml_conf() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
<foo>bar</foo>
EOF

  local expected=1
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_monitoring() {
  local yaml_file=
  yaml_file=$(mktemp)
  local monitoring_install=1
  cat > "${yaml_file}" <<EOF
---
profiles:
  monitoring:
    install: yes
EOF

  unset fai_monitoring_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Wrong fai_monitoring_install" \
               "${monitoring_install}" \
               "${fai_monitoring_install}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/conf-file-reader.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
