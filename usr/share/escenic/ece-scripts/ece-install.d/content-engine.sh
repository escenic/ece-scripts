# -*- mode: sh; sh-shell: bash; -*-
# ece-install module Content Engine specific code.

function get_deploy_white_list() {

  local deploy_white_list=""
  local presentation_deploy_white_list="escenic-admin $(get_publication_short_name_list)"
  local editor_deploy_white_list="escenic-admin escenic studio indexer-webservice webservice webservice-extensions preview-editor-ws"
  local search_deploy_white_list="solr indexer-webapp"

  if is_installing_post_ece6; then
    search_deploy_white_list="indexer-webapp"
  fi

  # user's deploy white list, if present, takes precedence.
  if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    deploy_white_list=${fai_presentation_deploy_white_list-$presentation_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    deploy_white_list=${fai_editor_deploy_white_list-$editor_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
    deploy_white_list=${fai_search_deploy_white_list-$search_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    local default_all_deploy_white_list="
        ${presentation_deploy_white_list}
        ${editor_deploy_white_list}
        ${search_deploy_white_list}
      "
    deploy_white_list=${fai_all_deploy_white_list-$default_all_deploy_white_list}
  else
    deploy_white_list=${fai_publication_deploy_white_list-""}
  fi

  echo ${deploy_white_list}
}

function get_publication_short_name_list() {
  local deploy_white_list=""

  if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    deploy_white_list=${fai_presentation_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    deploy_white_list=${fai_editor_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
    deploy_white_list=${fai_search_deploy_white_list}
  elif [ $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    deploy_white_list=${fai_all_deploy_white_list}
  fi
	
  if [[ -z "$deploy_white_list" && \
    -n "${fai_publication_domain_mapping_list}" ]]; then
    for el in $fai_publication_domain_mapping_list; do
      log el=$el

      old_ifs=$IFS
      IFS='#' read publication domain aliases <<< "$el"
      log publication=$publication domain=$domain aliases=$aliases
      IFS=',' read publication_name publication_war <<< "$publication"
      log publication_name=$publication_name publication_war=$publication_war
      IFS=$old_ifs
      if [ -z "${publication_war}" ]; then
        publication_war=${publication_name}.war
      fi
      deploy_white_list="${deploy_white_list} $(basename $publication_war .war)"
    done
  fi

  local short_name_list=""

  for el in $deploy_white_list; do
    if [ $(is_webapp_a_publication $el) -eq 1 ]; then
      short_name_list="${short_name_list} $el"
    fi
  done

  echo ${short_name_list}
}

function deploy_conf_package() {
  if [ -z $fai_conf_url ]; then
     return;
  fi
  local conf_file_url=$fai_conf_url

  if [ ! -d $escenic_cache_dir ] ; then
    mkdir -p $escenic_cache_dir
  fi 

  if [[ -n "${fai_conf_builder_http_user}" && \
      -n "${fai_conf_builder_http_password}" ]]; then
      local wget_auth="
          --http-user $fai_conf_builder_http_user
          --http-password $fai_conf_builder_http_password
        "
  fi

  local conf_file=$escenic_cache_dir/$(basename $conf_file_url)

  if [ -s $conf_file ] ; then
    print_and_log "Using previously downloaded conf file $conf_file"
  else
    print_and_log "Downloading $conf_file_url to $conf_file"
    run wget $wget_auth $wget_opts $conf_file_url \
      -O $conf_file
  fi

  if [ ! -s $conf_file ] ; then
    rm $conf_file
    print_and_log "Unable to download conf file $conf_file_url," \
      "aborting."
    remove_pid_and_exit_in_error
  fi

  print_and_log "Installing $(basename $conf_file_url) ..."
  local dpkg_opts=" --force-overwrite --force-confnew "
  run dpkg \
    $dpkg_opts \
    --install $conf_file
}

function set_search_host_and_ports() {
  search_host=${fai_search_host-$HOSTNAME}
  search_port=${fai_search_port-$default_app_server_port}
  solr_port=${fai_solr_port-8983}
}

## $1=<default instance name>
function install_ece_instance() {
  install_ece_third_party_packages

  ask_for_instance_name $1
  set_up_engine_directories

  set_archive_files_depending_on_profile

  create_ear_download_list

  download_escenic_components
  check_for_required_downloads
  set_up_ece_scripts
  set_up_engine_and_plugins

  # most likely, the user is _not_ installing from archives (EAR +
  # configuration bundle), hence the false test goes first.
  if [ $(is_installing_from_ear) -eq 0 ]; then
    if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
      set_up_assembly_tool
    fi
  else
    verify_that_files_exist_and_are_readable \
      $ece_instance_ear_file \
      $ece_instance_conf_archive
  fi

  if [[ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ||
        $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ||
        $install_profile_number -eq $PROFILE_ALL_IN_ONE
      ]]; then

    ## Since 2013-09-05 (e6958fb9) we've had a a chicken and the egg
    ## problem, set_up_app_server is dependent on Nursery
    ## configuration to be there, but
    ## set_up_basic_nursery_configuration (which again calls
    ## set_up_search_client_nursery_conf) is dependent on values set
    ## in set_up_app_server. Without these, the search related Nursery
    ## components get faulty entries.
    set_search_host_and_ports

    set_up_basic_nursery_configuration
    set_up_instance_specific_nursery_configuration
  fi

  set_up_app_server

  # We set a WAR white list for all profiles except all in one
  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
    local file=$escenic_conf_dir/ece-${instance_name}.conf
    print_and_log "Creating deployment white list in $file ..."
    set_conf_file_value \
      deploy_webapp_white_list \
      $(get_deploy_white_list) \
      $file
    if [ ! -z "$fai_environment" ] ; then
      set_conf_file_value \
        ece_environment \
        "$fai_environment" \
        $file
    fi
  fi
  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER -a \
    $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
    set_up_content_engine_cron_jobs
    install_memory_cache
    assemble_deploy_and_restart_type
    configure_special_plugins
    deploy_conf_package
  fi

  update_type_instances_to_start_up
  set_conf_file_value ece_unix_user $ece_user /etc/default/ece
  set_conf_file_value ece_unix_group $ece_group /etc/default/ece

  stop_and_clear_instance_if_requested
  leave_content_engine_trails

  admin_uri=http://$HOSTNAME:${appserver_port}/escenic-admin/
  add_next_step "New ECE instance $instance_name installed."
  add_next_step "Admin interface: $admin_uri"
  add_next_step "View installed versions with:" \
    " ece -i $instance_name versions"
  add_next_step "Type 'ece help' to see all the options of this script"
  add_next_step "Read its guide: /usr/share/doc/escenic/ece-guide.txt"
  add_next_step "/etc/default/ece lists all instances started at boot time"
}

function create_ear_download_list() {
  # sane default
  ear_download_list=

  if [ $(is_installing_from_ear) -eq 0 ]; then
    return;
  fi

  if [[ -n "${fai_builder_http_user}" && \
      -n "${fai_builder_http_password}" ]]; then
      local wget_auth="
          --http-user $fai_builder_http_user
          --http-password $fai_builder_http_password
        "
  fi

  # TODO: do I need to make this here?  Shouldn't it be here already?
  if [ ! -d $escenic_cache_dir ] ; then
    mkdir -p $escenic_cache_dir
  fi

  local ear_file=$escenic_cache_dir/$(basename $ece_instance_ear_file)

  if [ -s $ear_file ] ; then
    print_and_log "Using previously downloaded EAR file $ear_file"
  else
    print_and_log "Downloading $ece_instance_ear_file to $ear_file"
    run wget $wget_auth $wget_opts $ece_instance_ear_file \
      -O $ear_file
  fi

  if [ ! -s $ear_file ] ; then
    rm $ear_file
    print_and_log "Unable to download EAR file $ece_instance_ear_file," \
      "aborting."
    remove_pid_and_exit_in_error
  fi

  local distributions_txt=META-INF/escenic-distributions.txt

  # Verify that the ZIP file has an effective-pom.xml file
  run unzip -t -q $ear_file
  log "$ear_file was a valid ZIP file"

  if ! unzip &> /dev/null -t -q $ear_file $distributions_txt; then
    print_and_log "EAR file is missing $distributions_txt. Not resolving artifacts."
    return 0
  fi

  local gavs=$(unzip -qc $ear_file $distributions_txt | grep '^[a-z]')
  if ! grep -q . <<< "$gavs" ; then
    print_and_log "EAR's $distributions_txt had no maven artifacts in it properties.  Ignoring."
    log props=$props
    return 0
  fi

  log "Found these artifacts: " $gavs

  local coordinate
  for coordinate in $gavs; do
    local groupid
    local artifactid
    local version
    local packaging
    local classifier
    # coordinate is e.g. com.escenic:engine-dist:zip:bin:5.5.2.137014
    # or com.escenic.plugins.forum:forum:zip:3.2.1.132293
    # groupid:artifactid:[packaging:[classifier:]]version

    # chomp groupid: --> artifactid:[packaging:[classifier:]]version
    groupid=${coordinate/:*}
    coordinate=${coordinate#${groupid}:}

    # chomp artifactid: --> [packaging:[classifier:]]version
    artifactid=${coordinate/:*}
    coordinate=${coordinate#${artifactid}:}

    # chomp version --> [packaging[:classifier]]
    version=${coordinate/*:}
    coordinate=${coordinate%${version}}
    coordinate=${coordinate%:}

    classifier=
    packaging=

    if [ ! -z "$coordinate" ] ; then
      # chomp packaging --> [classifier]
      packaging=${coordinate/:*}
      coordinate=${coordinate#${packaging}}
      coordinate=${coordinate#:}
    fi

    if [ ! -z "$coordinate" ] ; then
      # chomp classifier
      classifier=$coordinate
      coordinate=
    fi

    ear_download_list="$ear_download_list \
       ${groupid//.//}/${artifactid}/$version/${artifactid}-${version}${classifier:+-${classifier}}.$packaging"

  done
}

function set_up_engine_and_plugins() {
  if [ $ece_software_setup_completed -eq 1 ]; then
    return
  fi
  if [ "${fai_package_enabled-0}" -eq 1 ]; then
    return
  fi

  print_and_log "Setting up the Escenic Content Engine & its plugins ..."
  make_dir $escenic_root_dir
  run cd $escenic_root_dir/

  for el in $technet_download_list $ear_download_list; do
    local file=$(basename $el)
    if [[ "$file" == *-SNAPSHOT* ]] ; then
      local el2
      local elf=${file/-dist}
      # Pick the first non-SNAPSHOT version.
      for el2 in $(dirname $file)/${file/SNAPSHOT/*} $(dirname $file)/${elf/SNAPSHOT/*} ; do
        if [ -r "$el2" ] ; then
          file=$(basename $el2);
          break;
        fi
      done
    fi

    verify_that_archive_is_ok $download_dir/$file

    if [ $(echo $file | \
      grep -E "^engine-[0-9]|^engine-trunk-SNAPSHOT|^engine-develop-SNAPSHOT|^engine-dist" | \
      wc -l) -gt 0 ]; then
      engine_dir=$(get_base_dir_from_bundle $download_dir/$file)
      engine_file=$file
    fi
  done

  if [ -n "$engine_dir" -a ! -d "${engine_dir}" ]; then
    run unzip -q -u -o $download_dir/${engine_file}
    if [ -h engine ]; then
      run rm engine
    fi

    run ln -s ${engine_dir} engine
  else
    debug "${engine_dir} is already there, skipping to next step."
  fi

  # we now extract all the plugins. We extract them in $escenic_root_dir
  # as we want to re-use them between minor updates of ECE.
  run cd $escenic_root_dir/
  for el in $technet_download_list $wf_download_list $ear_download_list; do
    local file=$(basename $el)
    # FIXME el will never be engine-* because it's the technet download list.  Should
    # this be [[ "$file" == ....
    if [[ "$el" == engine-* ]]; then
      continue
    fi
    # We handle AT explicitly in set_up_assembly_tool
    if [[ ${file} == assemblytool* ]]; then
      continue
    fi
    run unzip -q -u -o $download_dir/$file
  done

  ece_software_setup_completed=1
}

function _assembly_tool_should_set_up() {
  if [ "${fai_package_enabled-0}" -eq 0 ]; then
    return 0
  elif [[ "${fai_assembly_tool_install-0}" -eq 1 ]]; then
    return 0
  fi

  return 1
}

function _assembly_tool_install_binaries() {
  make_dir $(_assembly_tool_get_dir)/

  if [ "${fai_package_enabled-0}" -eq 1 ]; then
    # The user defines the packages/versions he/she wants in the YAML
    # file.
    :
  else
    if [ -e $download_dir/assemblytool*zip ]; then
      run unzip -q -u -o $download_dir/assemblytool*zip \
          -d "${escenic_root_dir}/assemblytool/"
    elif [ -e ${download}_dir/assemblytool*jar ]; then
      run unzip -q -u -o ${download_dir}/assemblytool*jar \
          -d "${escenic_root_dir}/assemblytool/"
    fi
  fi
}

function _assembly_tool_get_dir() {
  if [ "${fai_package_enabled-0}" -eq 0 ]; then
    echo "${escenic_root_dir}/assemblytool"
  else
    echo "${escenic_root_dir}/escenic-assemblytool"
  fi
}

function _assembly_tool_set_up_bootstrap_conf() {
  # adding an instance layer to the Nursery configuration
  run cp -r $(get_content_engine_dir)/siteconfig/bootstrap-skeleton \
    $(_assembly_tool_get_dir)/conf
  run cd $(_assembly_tool_get_dir)/conf/
  run cp -r layers/host layers/environment
  run cp -r layers/host layers/instance
  run cp -r layers/host layers/vosa
  run cp -r layers/host layers/server

  cat > layers/environment/Files.properties <<EOF
\$class=neo.nursery.FileSystemDepot
fileSystemRoot = $escenic_conf_dir/engine/environment/\${com.escenic.environment "unknown"}/
EOF
  cat > layers/instance/Files.properties <<EOF
\$class=neo.nursery.FileSystemDepot
fileSystemRoot = $escenic_conf_dir/engine/instance/\${com.escenic.instance "default"}/
EOF
  cat > layers/vosa/Files.properties <<EOF
\$class=neo.nursery.FileSystemDepot
fileSystemRoot = $escenic_conf_dir/engine/vosa/
EOF
  cat > layers/server/Files.properties <<EOF
\$class=neo.nursery.FileSystemDepot
fileSystemRoot = $escenic_conf_dir/engine/server/\${escenic.server "default"}/
EOF

  cat > Nursery.properties <<EOF
# Configuration layers set up by $(basename $0) @ $(date)

\$class=neo.nursery.Bootstrapper

# ECE :: default layer
layer.01 = /layers/default/Layer

# ECE :: plugins layer
layer.02 = /layers/addon/Layer

# VOSA :: common VOSA/SaaS layer
layer.03 = /layers/vosa/Layer

# Customer :: common layer
layer.04 = /layers/common/Layer

# Customer :: family/group layer (e.g. presentation, editorial)
layer.05 = /layers/family/Layer

# Customer :: environment layer (e.g. testing, staging, production)
layer.06 = /layers/environment/Layer

# Customer :: host specific layer
layer.07 = /layers/host/Layer

# Customer :: instance specific layer
layer.08 = /layers/instance/Layer

# Customer :: "escenic.server" specific layer, this layer is a
# combination of the host and the instance.
layer.09 = /layers/server/Layer
EOF

  # fixing the path to the Nursery configuration according to
  # escenic_conf_dir which may have been overridden by the user.
  for el in $(find $(_assembly_tool_get_dir)/conf -name Files.properties)
  do
    sed -i "s#/etc/escenic#${escenic_conf_dir}#g" $el
  done
}


function set_up_assembly_tool() {
  if ! _assembly_tool_should_set_up; then
    return
  fi

  print_and_log "Setting up the Assembly Tool ..."

  _assembly_tool_install_binaries
  _assembly_tool_set_up_bootstrap_conf

  # set up which plugins to use
  run cd $(_assembly_tool_get_dir)/
  make_dir plugins
  run cd plugins
  find ../../ -maxdepth 1 -type d | \
    grep -v assemblytool | \
    while read directory; do
    if [ $directory = "../../" ]; then
      continue
    fi

    # nuisance to get the community engine and analysis engine, but
    # not the engine
    if [ $(echo $directory | \
      grep engine | \
      grep -v community | \
      grep -v analysis | \
      wc -l) -gt 0 ]; then
      continue
    fi

    make_ln $directory
  done

  run cd $(_assembly_tool_get_dir)/
  run ant -q initialize
  sed -i "s~#\ engine.root\ =\ \.~engine.root=${escenic_root_dir}/engine~g" \
    assemble.properties \
    1>>$log 2>>$log
  exit_on_error "sed on assemble.properties"

  sed -i "s~\#\# plugins\ =\ /path/to/plugins~plugins=${escenic_root_dir}/assemblytool/plugins~g" \
    assemble.properties \
    1>>$log 2>>$log
  exit_on_error "sed on assemble.properties"

  make_dir $(_assembly_tool_get_dir)/publications

  # Set up a publication definition
  #
  # We only support one publication for now as it's becoming more and
  # more seldom to set up AT with ece-install. Instead, more and more
  # folks are using pre-built EARs to make the deployment as a part of
  # the ece-install process). Future enhancement would be to support
  # fai_publication_domain_mapping_list and
  # fai_<presentation|editor>_ear for creating publication definitions
  # and WARs.
  if [[ -n "${fai_publication_name}" && -n "${fai_publication_war}" ]]; then
    local file=$(_assembly_tool_get_dir)/publications/${fai_publication_name}.properties
    print_and_log "Creating a publication definition for publication" \
      $fai_publication_name "..."
    run cp ${fai_publication_war} \
      $(_assembly_tool_get_dir)/publications/${fai_publication_name}.war
    cat > $file <<EOF
name: ${fai_publication_name}
source-war: ${fai_publication_name}.war
context-root: ${fai_publication_name}
EOF
  fi
}

function _set_up_basic_nursery_configuration_by_copying() {
  print_and_log "Setting up basic Nursery configuration ..."

  # we always copy the default plugin configuration (even if there is
  # an archive)
  for el in $(_assembly_tool_get_dir)/plugins/*; do
    if [ ! -d $el/misc/siteconfig/ ]; then
      continue
    fi
    run cp -r $el/misc/siteconfig/* $common_nursery_dir/
  done

  # Then we see if we're using configuration archives, if yes, use the
  # JAAS and Nursery configuraiton from here.
  if [ $(is_using_conf_archive) -eq 1 ]; then
    print_and_log "Using the supplied Nursery & JAAS configuration from" \
      "bundle: $ece_instance_conf_archive"

    # the conf archive typically resides on the build server, hence we
    # set its authentication credentials here.
    wget_auth=$wget_builder_auth

    local a_tmp_dir=$(mktemp -d)
    download_uri_target_to_dir \
      $ece_instance_conf_archive \
      $a_tmp_dir
    local file=$a_tmp_dir/$(basename $ece_instance_conf_archive)

    run cd $a_tmp_dir
    extract_archive $file

    if [ -d ${a_tmp_dir}/engine/security ]; then
      run cp -r $a_tmp_dir/engine/security/ $common_nursery_dir/
    else
      print "Archive $ece_instance_conf_archive doesn't have JAAS config,"
      print "I'll use standard JAAS (engine/security) instead."
      run cp -r $(get_content_engine_dir)/security/ $common_nursery_dir/
    fi

    run cp -rn engine/siteconfig/config-skeleton/* $common_nursery_dir/
  elif [ -d $(get_content_engine_dir)/siteconfig/config-skeleton ] ; then
    print_and_log "I'm using Nursery & JAAS configuration (skeleton) " \
      "from $(get_content_engine_dir)"
    run cp -rn $(get_content_engine_dir)/siteconfig/config-skeleton/* \
      $common_nursery_dir/
    run cp -r $(get_content_engine_dir)/security/ $common_nursery_dir/
  else
    print_and_log "I'm creating an empty config tree for you, since" \
      "no content engine was downloaded."
    run mkdir -p $common_nursery_dir
  fi

  if [ -n "${a_tmp_dir}" ]; then
    run rm -rf ${a_tmp_dir}
  fi
}

function set_up_basic_nursery_configuration() {
  print_and_log "Setting up basic Nursery configuration ..."

  if [ "${fai_package_enabled-0}" -eq 0 ]; then
    _set_up_basic_nursery_configuration_by_copying
  fi

  public_host_name=$HOSTNAME:${appserver_port}
  if [ -n "$fai_public_host_name" ]; then
    public_host_name=$fai_public_host_name
  fi

  if [ -n "$user_host_name" ]; then
    public_host_name=$user_host_name
  fi

  cat > $common_nursery_dir/ServerConfig.properties <<EOF
databaseProductName=MySQL
filePublicationRoot=$escenic_data_dir/engine/
webPublicationRoot=http://${public_host_name}/
EOF
  # AFTER Content Engine 5.6, the Read and Update connectors are gone
  # replaced with ReadConnector.  Configure it appropriately based
  # on the presence of it in the common nursery dir.
  if [ -r $common_nursery_dir/connector/DataConnector.properties ] ; then
    cat > $common_nursery_dir/neo/io/managers/ContentManager.properties <<EOF
dataConnector=/connector/DataConnector
EOF
  else
    cat > $common_nursery_dir/neo/io/managers/ContentManager.properties <<EOF
readConnector=/connector/ReadConnector
updateConnector=/connector/UpdateConnector
EOF
  fi
  file=$common_nursery_dir/com/escenic/community/CommunityEngine.properties
  if [ -w ${file} ]; then
    if [ -r $common_nursery_dir/connector/DataConnector.properties ] ; then
      sed -i 's/jdbc\/ecome/jdbc\/ECE_DS/g' $file
      exit_on_error "sed on $file"
    else
      sed -i 's/jdbc\/ecome/jdbc\/ECE_UPDATE_DS/g' $file
      exit_on_error "sed on $file"
    fi
  elif [ ! -e ${file} ]; then
    print_and_log "I Could not find an ECOME configuration file," \
      "I assume you have not installed Community Engine."
  else
    print_and_log "Could not write to ${file}," \
      "Community Engine might not work because of this. "
    remove_pid_and_exit_in_error
  fi

  file=$common_nursery_dir/com/escenic/webstart/StudioConfig.properties

  cat >> $file <<EOF
# This font have been tested and works with (at least): English,
# Norwegian & Tamil. The font comes with (at least) MS Office and OS X
# 10.5 and up.
property.com.escenic.studio.font.macosx=Arial Unicode MS
property.com.escenic.studio.font.linux=Arial Unicode MS
property.com.escenic.studio.font.windows7=Arial Unicode MS
property.com.escenic.studio.font.windowsxp=Arial Unicode MS
property.com.escenic.studio.font.windowsvista=Arial Unicode MS

# We want to speed up downloading studio
property.jnlp.packEnabled=true
EOF

  set_up_search_client_nursery_conf
}

function set_up_instance_specific_nursery_configuration() {
  if [ "${fai_package_enabled-0}" -eq 1 ]; then
    return
  fi

  print_and_log "Setting up instance specific Nursery configuration ..."

  for el in $escenic_conf_dir/engine/instance/*; do
    i=$(( i + 1 ))
    if [ $(basename $el) = $instance_name ]; then
      rmi_port="8${i}23"
      run echo "port=$rmi_port" > $el/RMI.properties
    fi
  done

  nursery_context=neo/io/managers/HubConnectionManager.properties
  file=$escenic_conf_dir/engine/instance/$instance_name/$nursery_context
  make_dir $(dirname $file)

  # we don't touch it if the file already exists.
  if [ ! -e $file ]; then
    run echo "hostname=$HOSTNAME" >> $file
  fi
}

# Installs third party packages needed by the ECE (i.e. Java related).
# Also see install_common_os_packages for packages common to all
# servers in the architecture.
function install_ece_third_party_packages
{
  run_hook install_ece_third_party_packages.preinst
  print_and_log "Installing 3rd party packages needed by $type instances"

  if [ $on_debian_or_derivative -eq 1 ]; then
    if [ $on_ubuntu -eq 1 ]; then
      local version=$(lsb_release -s -r | sed "s#\.##g")

      add_apt_source \
        "deb http://archive.canonical.com/ $(lsb_release -s -c) partner"
    elif [ $on_debian -eq 1 ]; then
      code_name=$(lsb_release -s -c)
      has_non_free=$(grep $(lsb_release -s -c) \
        /etc/apt/sources.list | \
        egrep -v "^#|deb-src" | \
        grep -v security | \
        grep non-free | \
        wc -l)
      if [ $has_non_free -eq 0 ]; then
        add_apt_source "deb http://ftp.${mirror_country_suffix}.debian.org/debian/ $(lsb_release -s -c) contrib non-free"
      fi

      local version=$(lsb_release -s -r | sed "s#\.##g")
    fi

    if [ "$(has_oracle_java_installed)" -eq 0 ]; then
      install_oracle_java
    fi

    local packages="
      ant
      ant-contrib
      ant-optional
      libapr1
      libtcnative-1
      libmysql-java
      libxml2-utils
      memcached
      xml-twig-tools
      wget
      xmlstarlet
    "
  elif [ $on_redhat_or_derivative -eq 1 ]; then
    packages="
      ant
      ant-contrib
      ant-nodeps
      apr
      libxml2
      memcached
      mysql-connector-java
      tomcat-native
      wget
      xmlstarlet
    "

    install_oracle_java
  fi

  install_packages_if_missing $packages
  assert_commands_available ant java jar
}

ece_instance_ear_file=""
ece_instance_conf_archive=""

function set_archive_files_depending_on_profile()
{
  if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    ece_instance_ear_file=$fai_presentation_ear
    ece_instance_conf_archive=$fai_presentation_conf_archive
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    ece_instance_ear_file=$fai_editor_ear
    ece_instance_conf_archive=$fai_editor_conf_archive
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
    ece_instance_ear_file=$fai_search_ear
    ece_instance_conf_archive=$fai_search_conf_archive
  elif [ $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    ece_instance_ear_file=$fai_all_ear
    ece_instance_conf_archive=$fai_all_conf_archive
  elif [ $install_profile_number -eq $PROFILE_DB_SERVER ]; then
    ece_instance_ear_file=$fai_db_ear
    ece_instance_conf_archive=""
  else
    # All other profiles don't have EAR support.
    ece_instance_ear_file=""
    ece_instance_conf_archive=""
  fi
}

# Returns 1 if we're installing the ECE instances from a provided EAR
# file
function is_installing_from_ear()
{
  log install_profile_number=$install_profile_number
  log ece_instance_ear_file=$ece_instance_ear_file

  if [[ -z "$ece_instance_ear_file" ]]; then
    echo 0
    return
  fi

  echo 1
}

# Returns 1 if we're using a tarball with the Nursery & JAAS configuration.
function is_using_conf_archive(){
  log install_profile_number=$install_profile_number
  log ece_instance_conf_archive=$ece_instance_conf_archive

  if [[ -z "$ece_instance_conf_archive" ]]; then
    echo 0
    return
  fi

  echo 1
}

function _repackage_deploy_and_restart_type()
{
  if [ "$(is_using_conf_archive)" -eq 1 ]; then
    local ece_command="
      ece \
        -i ${instance_name} \
        -t ${type} \
        repackage \
        stop \
        deploy \
        start \
        --uri ${ece_instance_ear_file}
     "
  else
    local ece_command="
      ece \
        -i ${instance_name} \
        -t ${type} \
        repackage \
        stop \
        deploy \
        start
    "
  fi

  su - "${ece_user}" -c "${ece_command}" &>> "${log}"
  exit_on_error "su - ${ece_user} -c ${ece_command}"
}

function assemble_deploy_and_restart_type()
{
  set_correct_permissions

  if [ "${fai_package_enabled-0}" -eq 1 ]; then
    _repackage_deploy_and_restart_type
    return
  fi

  # need to run clean here since we might be running multiple profiles
  # in the same ece-install process.
  ece_command="ece -i $instance_name -t $type clean assemble deploy restart"
  if [ $(is_installing_from_ear) -eq 1 ]; then
    ece_command="ece -i $instance_name \
      -t $type \
      deploy --uri $ece_instance_ear_file \
      restart"
    print_and_log "Deploying the $ece_instance_ear_file on" \
      "instance $instance_name and restarting it ..."
  else
    print_and_log "Assembling, deploying & starting $instance_name ..."
  fi

  su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  exit_on_error "su - $ece_user -c \"$ece_command\""
}

function set_up_engine_directories() {
  local el=
  for el in $engine_dir_list; do
    make_dir "${el}"
    run chown -R "${ece_user}:${ece_group}" "${el}"
  done
}

function leave_content_engine_trails() {
  leave_trail "trail_public_host_name=${public_host_name}"
}

## stop the ECE or EAE being installed and clear its logs, if so
function stop_and_clear_instance_if_requested() {
  local go_ahead=0

  if [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    go_ahead=${fai_analysis_stop_and_clear-0}
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    go_ahead=${fai_editor_stop_and_clear-0}
  elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    go_ahead=${fai_presentation_stop_and_clear-0}
  elif [ $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    go_ahead=${fai_all_stop_and_clear-0}
  fi

  if [ $go_ahead -eq 1 ]; then
    print_and_log "Stopping and clearing ${instance_name}'s work & log files:"
    local ece_command="ece -i ${instance_name} -t ${type} clean stop"
    run su - ${ece_user} -c "$ece_command"
    local dir_list="
      ${escenic_log_dir}
      ${escenic_cache_dir}
      ${escenic_crash_dir}
      ${tomcat_base}/logs
    "
    for el in $dir_list; do
      if [ ! -d "$el" ]; then
        continue
      fi
      log "Removing all files in $el ..."
      run rm -rf $el/*
    done

  fi
}

## called for presentation & editorial profiles
function set_up_search_client_nursery_conf() {
  local solr_base_url=http://${search_host}:${solr_port}/solr
  # Need to fix this hardcoded editoral search url, when we haved 
  # machine installation profile
  local solr_search_url=${solr_base_url}/editorial/select
  local  dir=$common_nursery_dir/com/escenic/webservice/search
  make_dir $dir

  if [ ${fai_search_legacy-0} -eq 1 ]; then
      solr_base_url=http://${search_host}:${search_port}/solr
      solr_search_url=${solr_base_url}/select
  fi

  echo "solrURI=${solr_search_url}" \
    >> $dir/DelegatingSearchEngine.properties

  dir=$common_nursery_dir/com/escenic/framework/search/solr
  make_dir $dir
  
  # We need to get rid of this legacy search checking every
  # time. TODO: Rename the legacy solr editorial core from collection1
  # to editorial so that it syncs together with the new Solr 6
  # implementation.
  if [ ${fai_search_legacy-0} -eq 1 ]; then
    solr_search_url=${solr_base_url}/presentation/select
  else
    if [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
      solr_search_url=${solr_base_url}/editorial/select
    else
      solr_search_url=${solr_base_url}/presentation/select
    fi
  fi
  echo "solrServerURI=${solr_search_url}" \
    >>  $dir/SolrSearchEngine.properties

  dir=$common_nursery_dir/com/escenic/lucy
  make_dir $dir
  echo "solrURI=http://${solr_search_url}" \
    >> $dir/LucySearchEngine.properties

  dir=$common_nursery_dir/com/escenic/forum/search/lucy
  make_dir $dir
  echo "solrURI=${solr_search_url}" \
    >> $dir/SearchEngine.properties

}

function set_up_content_engine_cron_jobs() {
  local file=/etc/cron.daily/remove-old-escenic-cache-files

  if [ -e $file ]; then
    return
  fi

  # paranoid, if someone/thing has unset this internal, ece-install
  # variable, we fail here
  if [ -z "${escenic_cache_dir}" ]; then
    remove_pid_and_exit_in_error \
      "Something is serously wrong, escenic_cache_dir is unset"
  fi

  print_and_log "Setting up cron job $file ..."
  cat > $file <<EOF
#! /bin/bash -e

# Created by $(basename $0) @ $(date)
#
# cron script to remove old cache files. These are the images that ECE
# generates whenever someone requests an image version (often referred
# to as ALTERNATE in the URL & content-type).

# This directory should correspond to the path which the
# com.escenic.presentation.servlet.multimedia.CacheFilter servlet
# filter writes to. (This needs to be set in each of the publication
# webapp's web.xml).
dir=${escenic_cache_dir}/engine/binary
log=/var/log/\$(basename \$0).log

function exit_if_dir_is_unset_or_doesnt_exist() {
  if [ -z "\${dir}" ]; then
    echo "The dir varialbe is unset :-(" >> \${log}
    exit 1
  fi
  if [ ! -d \${dir} ]; then
    echo \$dir "doesn't exist" >> \${log}
    exit 0
  fi
}

function exit_if_user_doesnt_own_dir() {
  local user_id=\$(id -u ${ece_user})
  # This (stac -c) is Linux specific
  local dir_owner_id=\$(stat -c "%u" \${dir})

  if [[ \${user_id} != \${dir_owner_id} ]]; then
    echo ${ece_user} "doesn't own \${dir} skipping \$(basename \$0)" >> \${log}
    exit 0
  fi
}

exit_if_dir_is_unset_or_doesnt_exist
exit_if_user_doesnt_own_dir

echo "Running \$(basename \$0) @ \$(date)" >> \${log}
su - ${ece_user} -c "nice find \${dir} -type f -daystart -atime +15 -delete"
su - ${ece_user} -c "nice find \${dir} -type d -empty -delete"
EOF

  run chmod +x $file
}
