# Configuration Reference for ece-install

`ece-install` can be configured either in YAML (new) or `.conf`
(old). You pass the file the same way regardless of format:
```
# ece-install -f <file>.yaml
# ece-install -f <file>.conf
```

Both versions are listed below, grouped by topic.

## environment

```
environment:
  type: ${environment_type}
  java_home: ${foo_java_home}
  java_version: ${foo_java_version}
  skip_password_checks: true
  conf_url: ${conf_url}
  apt:
    escenic:
      pool: ${apt_pool}
  maven:
    repositories:
      - ${mvn_repo1}
      - ${mvn_repo2}
```

- `ece-install.conf` equivalent: `java_home`
- `ece-install.conf` equivalent: `fai_environment`
- `ece-install.conf` equivalent: `fai_server_java_version`
- `ece-install.conf` equivalent: `fai_maven_repositories`
- `ece-install.conf` equivalent: `fai_conf_url`

## editor

```
profiles:
  editor:
    install: yes
    port: ${editor_port}
    host: ${editor_host}
    name: ${editor_name}
    redirect: ${editor_redirect}
    shutdown: ${editor_shutdown}
```

- `ece-install.conf` equivalent: `fai_editor_install`
- `ece-install.conf` equivalent: `fai_editor_port`
- `ece-install.conf` equivalent: `fai_editor_shutdown`
- `ece-install.conf` equivalent: `fai_editor_redirect`
- `ece-install.conf` equivalent: `fai_editor_name`


## presentation

```
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
```

- `ece-install.conf` equivalent: `fai_presentation_ear`
- `ece-install.conf` equivalent: `fai_presentation_environment`
- `ece-install.conf` equivalent: `fai_presentation_install`
- `ece-install.conf` equivalent: `fai_presentation_name`
- `ece-install.conf` equivalent: `fai_presentation_port`
- `ece-install.conf` equivalent: `fai_presentation_redirect`
- `ece-install.conf` equivalent: `fai_presentation_shutdown`
- `ece-install.conf` equivalent: `fai_presentation_deploy_white_list`
- `ece-install.conf` equivalent: `fai_presentation_search_indexer_ws_uri`


## db

```
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
```

- `ece-install.conf` equivalent: `fai_db_install`
- `ece-install.conf` equivalent: `fai_db_master`
- `ece-install.conf` equivalent: `fai_db_user`
- `ece-install.conf` equivalent: `fai_db_password`
- `ece-install.conf` equivalent: `fai_db_schema`
- `ece-install.conf` equivalent: `fai_db_host`
- `ece-install.conf` equivalent: `fai_db_port`
- `ece-install.conf` equivalent: `fai_db_ear`
- `ece-install.conf` equivalent: `fai_db_drop_old_db_first`
- `ece-install.conf` equivalent: `fai_db_replication`

## cache
```
profiles:
  cache:
    install: yes
```

- `ece-install.conf` equivalent: `fai_presentation_install`

## monitoring
```
profiles:
  monitoring:
    install: yes
```

- `ece-install.conf` equivalent: `fai_monitoring_install`

## credentials

```
credentials:
  - site: maven.escenic.com
    user: ${escenic_download_user}
    password: ${escenic_download_password}
  - site: builder
    user: ${builder_download_user}
    password: ${builder_download_password}
```

- `ece-install.conf` equivalent: `technet_user`
- `ece-install.conf` equivalent: `technet_password`
- `ece-install.conf` equivalent: `fai_builder_http_user`
- `ece-install.conf` equivalent: `fai_builder_http_password`
- `ece-install.conf` equivalent: `fai_conf_builder_http_user`
- `ece-install.conf` equivalent: `fai_conf_builder_http_password`


## create_publication


```
profiles:
   publications:
     - name: ${publication1_name}
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
```

- `ece-install.conf` equivalent: `fai_publication_domain_mapping_list`
- `ece-install.conf` equivalent: `fai_publication_ear`
- `ece-install.conf` equivalent: `fai_publication_war_remove_file_list`
- `ece-install.conf` equivalent: `fai_publication_environment`
- `ece-install.conf` equivalent: `fai_publication_webapps`
- `ece-install.conf` equivalent: `fai_publications_webapps # arg, the plural`


## publication


```
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
```

- `ece-install.conf` equivalent: `fai_publication_domain_mapping_list`

## packages

```
packages:
  - name: ${package_name}
    version: ${package_version}
```
- `ece-install.conf` equivalent: `fai_package_map`
  declare -A fai_package_map

## packages_multiple


```
packages:
  - name: ${package_name}
    version: ${package_version}
  - name: ${package_name_without_version}
```
- `ece-install.conf` equivalent: `fai_package_map`
  declare -A fai_package_map

## use_escenic_packages

```
packages:
  foo: 1
```

- `ece-install.conf` equivalent: `fai_package_enabled`

## restore

```
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
```
- `ece-install.conf` equivalent: `fai_restore_pre_wipe_solr`
- `ece-install.conf` equivalent: `fai_restore_pre_wipe_all`
- `ece-install.conf` equivalent: `fai_restore_pre_wipe_logs`
- `ece-install.conf` equivalent: `fai_restore_pre_wipe_cache`
- `ece-install.conf` equivalent: `fai_restore_pre_wipe_crash`
- `ece-install.conf` equivalent: `fai_restore_from_backup`
- `ece-install.conf` equivalent: `fai_restore_data_files`
- `ece-install.conf` equivalent: `fai_restore_software_binaries`
- `ece-install.conf` equivalent: `fai_restore_db`
- `ece-install.conf` equivalent: `fai_restore_configuration`
- `ece-install.conf` equivalent: `fai_restore_from_file`

## analysis


```
profiles:
  analysis:
    install: yes
    name: ${analysis_name}
    port: ${analysis_port}
    host: ${analysis_host}
    shutdown: ${analysis_shutdown}
    redirect: ${analysis_redirect}
```

- `ece-install.conf` equivalent: `fai_analysis_install`
- `ece-install.conf` equivalent: `fai_analysis_name`
- `ece-install.conf` equivalent: `fai_analysis_port`
- `ece-install.conf` equivalent: `fai_analysis_host`
- `ece-install.conf` equivalent: `fai_analysis_shutdown`
- `ece-install.conf` equivalent: `fai_analysis_redirect`

## analysis_db


```
profiles:
  analysis_db:
    install: yes
    user: ${analysis_db_user}
    password: ${analysis_db_password}
    schema: ${analysis_db_schema}
```

- `ece-install.conf` equivalent: `fai_analysis_db_install`
- `ece-install.conf` equivalent: `fai_analysis_db_user`
- `ece-install.conf` equivalent: `fai_analysis_db_password`
- `ece-install.conf` equivalent: `fai_analysis_db_schema`

## search

```
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
```

- `ece-install.conf` equivalent: `fai_search_install`
- `ece-install.conf` equivalent: `fai_search_host`
- `ece-install.conf` equivalent: `fai_search_port`
- `ece-install.conf` equivalent: `fai_search_shutdown`
- `ece-install.conf` equivalent: `fai_search_redirect`
- `ece-install.conf` equivalent: `fai_search_name`
- `ece-install.conf` equivalent: `fai_search_legacy`
- `ece-install.conf` equivalent: `fai_search_for_editor`
- `ece-install.conf` equivalent: `fai_search_ear`
- `ece-install.conf` equivalent: `fai_search_indexer_ws_uri`


## editor_install_multi_profiles
```
profiles:
  editor:
    install: yes
  search:
    install: yes
  db:
    install: no
```

- `ece-install.conf` equivalent: `fai_editor_install`
- `ece-install.conf` equivalent: `fai_search_install`
- `ece-install.conf` equivalent: `fai_db_install`


## db
```
profiles:
  db:
    install: yes
```

- `ece-install.conf` equivalent: `fai_db_install`

## cache

```
profiles:
  cache:
    install: yes
    port: ${cache_port}
    conf_dir: ${cache_conf_dir}
    backends:
      - ${cache_be1}
      - ${cache_be2}
```

- `ece-install.conf` equivalent: `fai_cache_install`
- `ece-install.conf` equivalent: `fai_cache_backends`
- `ece-install.conf` equivalent: `fai_cache_conf_dir`
- `ece-install.conf` equivalent: `fai_cache_port`

---
Reference guide generated: Mon Mar 13 11:47:16 CET 2017
