function set_up_jdbc_library() {
  print_and_log "Setting up the jdbc driver"
  if [ -n "$jdbc_driver" -a -e "$jdbc_driver" ]; then
    make_ln $jdbc_driver
  elif [ $db_vendor = "mariadb" ]; then
    local mariadb_jdbc_url=https://downloads.mariadb.com/Connectors/java/connector-java-2.0.1/mariadb-java-client-2.0.1.jar
    print_and_log "Downloading MariaDB jdbc driver ${mariadb_jdbc_url}"
    local mariadb_jdbc_jar=${mariadb_jdbc_url##*/}
    download_uri_target_to_dir \
      "${mariadb_jdbc_url}" \
      "${download_dir}" \
      "${mariadb_jdbc_jar}"
    run cp "${download_dir}/${mariadb_jdbc_jar}" "${tomcat_base}/lib"
  else
    make_ln /usr/share/java/mysql-connector-java.jar      
  fi
}

function set_apr_lib_dir_in_ece_instance_conf_if_needed() {
  find /usr/lib* -maxdepth 3 -name libtcnative-1.so.0 |
    while read -r apr_lib; do
      set_ece_instance_conf apr_lib_dir "${apr_lib%/*}"
    done
}

function set_up_app_server() {
  print_and_log "Setting up the application server ..."

  if [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    appserver_port=${fai_editor_port-${default_app_server_port}}
    shutdown_port=${fai_editor_shutdown-${default_app_server_shutdown}}
    redirect_port=${fai_editor_redirect-${default_app_server_redirect}}
    leave_trail "trail_editor_host=${HOSTNAME}"
    leave_trail "trail_editor_port=${fai_editor_port-${default_app_server_port}}"
  elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    appserver_port=${fai_presentation_port-${default_app_server_port}}
    shutdown_port=${fai_presentation_shutdown-${default_app_server_shutdown}}
    redirect_port=${fai_presentation_redirect-${default_app_server_redirect}}
    leave_trail "trail_presentation_host=${HOSTNAME}"
    leave_trail "trail_presentation_port=${fai_presentation_port-${default_app_server_port}}"
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
    appserver_port=${fai_search_port-${default_app_server_port}}
    shutdown_port=${fai_search_shutdown-${default_app_server_shutdown}}
    redirect_port=${fai_search_redirect-${default_app_server_redirect}}
    leave_trail "trail_search_host=${HOSTNAME}"
    leave_trail "trail_search_port=${fai_search_port-${default_app_server_port}}"
  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    appserver_port=${fai_analysis_port-${default_app_server_port}}
    shutdown_port=${fai_analysis_shutdown-${default_app_server_shutdown}}
    redirect_port=${fai_analysis_redirect-${default_app_server_redirect}}
    leave_trail "trail_analysis_host=${HOSTNAME}"
    leave_trail "trail_analysis_port=${fai_analysis_port-${default_app_server_port}}"
  elif [ $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    leave_trail "trail_all_port=${default_app_server_port}"
    leave_trail "trail_all_shutdown=${default_app_server_shutdown}"
  fi

  if [ -z "$appserver_port" ]; then
    appserver_port=${default_app_server_port}
  fi
  if [ -z "$shutdown_port" ]; then
    shutdown_port=${default_app_server_shutdown}
  fi
  if [ -z "$redirect_port" ]; then
    redirect_port=${default_app_server_redirect}
  fi

  set_db_settings_from_fai_conf
  set_db_defaults_if_not_set

  user_indexer_ws_uri=${fai_search_indexer_ws_uri}

  if [ -n "$user_indexer_ws_uri" ]; then
    indexer_ws_uri=$user_indexer_ws_uri
  else
    indexer_ws_uri=http://${HOSTNAME}:${appserver_port}/indexer-webservice/index/
  fi

  user_presentation_indexer_ws_uri=${fai_presentation_search_indexer_ws_uri}

  if [ -n "$user_presentation_indexer_ws_uri" ]; then
    presentation_indexer_ws_uri=$user_presentation_indexer_ws_uri
  else
    presentation_indexer_ws_uri=http://${HOSTNAME}:${appserver_port}/indexer-webservice/presentation-index/
  fi

  leave_trail "trail_presentation_indexer_ws_uri=${presentation_indexer_ws_uri}"

  search_host=${fai_search_host-$HOSTNAME}
  search_port=${fai_search_port-$default_app_server_port}
  solr_port=${fai_solr_port-8983}

  download_tomcat $download_dir
  local tomcat_archive=$(
    find $download_dir \
      -name "apache-tomcat*.tar.gz" | \
      tail -1
  )
  tomcat_dir=$(get_base_dir_from_bundle $tomcat_archive)

  run cd $appserver_parent_dir
  run tar xzf $download_dir/${tomcat_dir}.tar.gz

  if [ -e tomcat ]; then
    run rm -r tomcat
  fi
  run ln --symbolic --force ${tomcat_dir} tomcat

  tomcat_home=${appserver_parent_dir}/tomcat
  tomcat_base=${appserver_parent_dir}/tomcat-${instance_name}

  if [ ! -d $tomcat_base ] ; then
    make_dir $tomcat_base
  fi
  run cp -rn ${appserver_parent_dir}/${tomcat_dir}/conf ${tomcat_base}/.

  for el in bin escenic/lib lib work logs temp webapps; do
    make_dir $tomcat_base/$el
  done

  set_ece_instance_conf tomcat_base $tomcat_base
  set_ece_instance_conf tomcat_home $tomcat_home
  set_ece_instance_conf appserver_port $appserver_port
  set_appropriate_jvm_heap_sizes
  set_http_auth_credentials_if_needed
  set_apr_lib_dir_in_ece_instance_conf_if_needed

  run cd $tomcat_base/lib

  set_up_jdbc_library

  # it's important to append (and not pre-pend) the ECE libraries so
  # that things put it in the standard loader behaves as expected,
  # such as log4j configuration put in ${tomcat.base}/lib.
  local file=$tomcat_base/conf/catalina.properties
  common_loader=$(grep ^common.loader $file)
  escaped_common_loader=$(get_escaped_bash_string ${common_loader})
  escenic_loader=",$\{catalina.base\}/escenic/lib/*.jar"
  old=$(get_escaped_bash_string ${common_loader})
  new=${escaped_common_loader}$(get_escaped_bash_string ${escenic_loader})
  run sed -i "s#${old}#${new}#g" $file

  local jdbc_package_name=com.mysql.jdbc.Driver
  if [ ! -z $db_vendor ] && [ $db_vendor = "mariadb" ]; then
    jdbc_package_name=org.mariadb.jdbc.Driver
  fi
  
  cat > $tomcat_base/conf/server.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<Server port="$shutdown_port" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JasperListener" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase"
              auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml"
    />
EOF
  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER \
    -a $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
    # AFTER Content Engine 5.6, the Read and Update connectors are gone
    # replaced with ReadConnector.  Configure it appropriately based
    # on the presence of it in the common nursery dir.
    if [ ! -r $common_nursery_dir/connector/DataConnector.properties ] ; then
      cat >> $tomcat_base/conf/server.xml <<EOF
    <Resource
        name="jdbc/ECE_READ_DS"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="400"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="${jdbc_package_name}"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
EOF
    fi
    if [ -r $common_nursery_dir/connector/DataConnector.properties ] ; then
      local ds=ECE_DS
      local max=500
    else
      local ds=ECE_UPDATE_DS
      local max=100
    fi

    cat >> $tomcat_base/conf/server.xml <<EOF
    <Resource
        name="jdbc/$ds"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="$max"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="${jdbc_package_name}"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
EOF
  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    cat >> $tomcat_base/conf/server.xml <<EOF
    <Resource
        name="jdbc/eae-qs/qs"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="400"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="${jdbc_package_name}"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
    <Resource
        name="jdbc/eae-logger/logger"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="100"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="${jdbc_package_name}"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
EOF
  fi

  cat >> $tomcat_base/conf/server.xml <<EOF
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="${appserver_port}"
               protocol="HTTP/1.1"
               connectionTimeout="20000"
               URIEncoding="UTF-8"
               compression="off"
               redirectPort="${redirect_port}"
    />
    <Connector port="${redirect_port}"
               protocol="HTTP/1.1"
               connectionTimeout="20000"
               URIEncoding="UTF-8"
               proxyPort="443"
               scheme="https"
    />
EOF

  if [[ ${fai_editor_install-0} -eq 1 ||
        ${fai_presentation_install-0} -eq 1 ]]; then
    cat >> $tomcat_base/conf/server.xml <<EOF
    <Connector port="${fai_sse_proxy_ece_port-8083}"
               protocol="HTTP/1.1"
               connectionTimeout="20000"
               URIEncoding="UTF-8"
               compression="off"
               redirectPort="${fai_sse_proxy_ece_redirect-8443}"
               proxyPort="${fai_sse_proxy_exposed_port-80}"
    />
EOF
  fi

  cat >> $tomcat_base/conf/server.xml <<EOF
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
      <Valve className="org.apache.catalina.valves.AccessLogValve"
             prefix="access."
             suffix=".log"
             pattern="common"/>
      <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
             digest="md5"
             resourceName="UserDatabase"/>
      <Host name="localhost"
            appBase="webapps"
            unpackWARs="true"
            autoDeploy="true"
            xmlValidation="false"
            xmlNamespaceAware="false">
      </Host>
EOF
  if [[ ($install_profile_number == $PROFILE_EDITORIAL_SERVER || \
    $install_profile_number == $PROFILE_PRESENTATION_SERVER || \
    $install_profile_number == $PROFILE_ALL_IN_ONE) ]]; then
    cat >> $tomcat_base/conf/server.xml <<EOF
        </Engine>
  </Service>
  <Service name="Catalina">
    <Connector port="${default_app_server_publication_port}"
               protocol="HTTP/1.1"
               connectionTimeout="20000"
               URIEncoding="UTF-8"
               compression="off"
               redirectPort="${redirect_port}"
               />
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
      <Valve className="org.apache.catalina.valves.AccessLogValve"
             prefix="access-publications."
             suffix=".log"
             pattern="common"
             />
      <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
             digest="md5"
             resourceName="UserDatabase"/>
EOF
  fi

  cat >> $tomcat_base/conf/server.xml <<EOF
    </Engine>
  </Service>
</Server>
EOF

  if [ ! -e $tomcat_base/conf/context.xml ] ; then
    cat > $tomcat_base/conf/context.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<Context/>
EOF

  xmlstarlet ed -P -L \
     -s /Context -t elem -n WatchedResource -v WEB-INF/web.xml \
     $tomcat_base/conf/context.xml
  fi

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER -a \
    $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then

    # Insert the ResourceLink element.
    local el
    if [ -r $common_nursery_dir/connector/DataConnector.properties ] ; then
      local DSs="_"
    else
      local DSs="_READ_ _UPDATE_"
    fi
    for el in $DSs ; do
      xmlstarlet ed -P -L \
       -s /Context -t elem -n TMP -v '' \
       -i //TMP -t attr -n global -v jdbc/ECE${el}DS \
       -i //TMP -t attr -n name -v jdbc/ECE${el}DS \
       -i //TMP -t attr -n type -v javax.sql.DataSource \
       -r //TMP -v ResourceLink \
       $tomcat_base/conf/context.xml
    done
  fi

  local solr_editorial_url=http://${search_host}:${solr_port}/solr/editorial
  local solr_presentation_url=http://${search_host}:${solr_port}/solr/presentation
  if [ ${fai_search_legacy-0} -eq 1 ]; then
    solr_editorial_url=http://${search_host}:${search_port}/solr/collection1
    solr_presentation_url=http://${search_host}:${search_port}/solr/presentation
  fi

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
    xmlstarlet ed -P -L \
       -s /Context -t elem -n TMP -v '' \
       -i //TMP -t attr -n name -v escenic/solr-base-uri \
       -i //TMP -t attr -n value -v "${solr_editorial_url}" \
       -i //TMP -t attr -n type -v java.lang.String \
       -i //TMP -t attr -n override -v false \
       -r //TMP -v Environment \
       $tomcat_base/conf/context.xml
  fi

  if [ $install_profile_number -eq $PROFILE_SEARCH_SERVER -o \
       $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then

     xmlstarlet ed -P -L \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n name -v escenic/indexer-webservice \
       -i /Context/TMP -t attr -n value -v ""${indexer_ws_uri} \
       -i /Context/TMP -t attr -n type -v java.lang.String \
       -i /Context/TMP -t attr -n override -v true \
       -r //TMP -v Environment \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n name -v escenic/index-update-uri \
       -i /Context/TMP -t attr -n value -v ${solr_editorial_url}/update/ \
       -i /Context/TMP -t attr -n type -v java.lang.String \
       -i /Context/TMP -t attr -n override -v true \
       -r //TMP -v Environment \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n name -v escenic/head-tail-storage-file \
       -i /Context/TMP -t attr -n value -v $escenic_data_dir/engine/head-tail.index \
       -i /Context/TMP -t attr -n type -v java.lang.String \
       -i /Context/TMP -t attr -n override -v true \
       -r //TMP -v Environment \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n name -v escenic/failing-documents-storage-file \
       -i /Context/TMP -t attr -n value -v $escenic_data_dir/engine/failures.index \
       -i /Context/TMP -t attr -n type -v java.lang.String \
       -i /Context/TMP -t attr -n override -v true \
       -r //TMP -v Environment \
       $tomcat_base/conf/context.xml
   print_and_log "Finished adding solr configuration for search"
   print_and_log "Started adding context configuration for indexer-webapp-presentation"
 
   mkdir -p $tomcat_base/conf/Catalina/localhost/

   cat > $tomcat_base/conf/Catalina/localhost/indexer-webapp-presentation.xml <<EOF
    <Context docBase="$\\{catalina.base}/webapps/indexer-webapp">
      <Environment name="escenic/solr-base-uri" value="${solr_presentation_url}" type="java.lang.String" override="true"/>
      <Environment name="escenic/indexer-webservice" value="${presentation_indexer_ws_uri}" type="java.lang.String" override="true"/>
      <Environment name="escenic/index-update-uri" value="${solr_presentation_url}/update/" type="java.lang.String" override="true"/>
      <Environment name="escenic/head-tail-storage-file" value="$escenic_data_dir/engine/head-tail-presentation.index" type="java.lang.String" override="true"/>
      <Environment name="escenic/failing-documents-storage-file" value="$escenic_data_dir/engine/failures-presentation.index" type="java.lang.String" override="true"/>
   </Context>
EOF
   pretty_print_xml $tomcat_base/conf/Catalina/localhost/indexer-webapp-presentation.xml
   print_and_log "Finished adding context for indexer-webapp-presentation"

  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    xmlstarlet ed -P -L \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n global -v jdbc/eae-logger/logger \
       -i /Context/TMP -t attr -n name -v jdbc/eae-logger/logger \
       -i /Context/TMP -t attr -n type -v javax.sql.DataSource \
       -r //TMP -v ResourceLink \
       -s /Context -t elem -n TMP -v '' \
       -i /Context/TMP -t attr -n global -v jdbc/eae-qs/qs \
       -i /Context/TMP -t attr -n name -v jdbc/eae-qs/qs \
       -i /Context/TMP -t attr -n type -v javax.sql.DataSource \
       -r //TMP -v ResourceLink \
       $tomcat_base/conf/context.xml
  fi

  pretty_print_xml $tomcat_base/conf/context.xml
  set_up_logging
}

function set_up_logging() {
  print_and_log "Setting up Tomcat to use log4j ..."
  log4j_download_the_tomcat_juli_libraries_and_copy_these_to_cl
  log4j_ensure_java_util_logging_is_not_doing_anything
  log4j_create_configuration_file
}

function set_appropriate_jvm_heap_sizes() {
  # in MB
  local heap_size=${default_app_server_heap_size}

  if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    heap_size=${fai_presentation_heap_size-${default_app_server_heap_size}}
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    heap_size=${fai_editor_heap_size-${default_app_server_heap_size}}
  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_DB_SERVER ]; then
    heap_size=${fai_analysis_heap_size-${default_app_server_heap_size}}
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
    heap_size=${fai_search_heap_size-${default_app_server_heap_size}}
  fi

  local percent=70
  local total_size=$(get_total_memory_in_mega_bytes)

  if [ $total_size -lt $heap_size ]; then
    print_and_log "$(yellow WARNING) $HOSTNAME has only $total_size MBs of" \
      "memory, I will use ${percent}% of this for the JVM heap sizes, but you" \
      "should really consider adding more RAM so that" \
      "the $instance_name instance gets at least 2GBs"

    heap_size=$(echo "$total_size * 0.${percent}" | bc | cut -d'.' -f1)
  fi

  set_ece_instance_conf min_heap_size "${heap_size}m"
  set_ece_instance_conf max_heap_size "${heap_size}m"
}

function set_http_auth_credentials_if_needed() {
  if [[ -n "$fai_builder_http_user" && -n "$fai_builder_http_password" ]]; then
    set_ece_instance_conf builder_http_user "$fai_builder_http_user"
    set_ece_instance_conf builder_http_password "$fai_builder_http_password"
    leave_trail trail_builder_http_user="$fai_builder_http_user"
    leave_trail trail_builder_http_password="$fai_builder_http_password"
  fi

  local http_user=""
  local http_password=""

  if [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    http_user=${fai_editor_escenic_admin_http_user}
    http_password=${fai_editor_escenic_admin_http_password}
  elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    http_user=${fai_presentation_escenic_admin_http_user}
    http_password=${fai_presentation_escenic_admin_http_password}
  fi

  if [[ -n "$http_user" && -n "$http_password" ]]; then
    set_ece_instance_conf escenic_admin_http_user "$http_user"
    set_ece_instance_conf escenic_admin_http_password "$http_password"
  fi
}

function log4j_create_configuration_file() {
  print_and_log "Setting up proper log4j & Java logging configuration ..."

  cat > $common_nursery_dir/trace.properties <<EOF
# generated by $(basename $0) @ $(date --iso)

######################################################################
# The default logger (this is the catch all logger)
log4j.rootLogger=ERROR, TOMCAT
log4j.additivity.com=false
log4j.additivity.neo=false
# Get rid of serialization errors to memcached.
log4j.category.com.danga.MemCached.MemCachedClient=FATAL

######################################################################
# The ECE specific logging
log4j.appender.ECELOG=org.apache.log4j.DailyRollingFileAppender
log4j.appender.ECELOG.File=$escenic_log_dir/\${com.escenic.instance}-messages
log4j.appender.ECELOG.layout=org.apache.log4j.PatternLayout
log4j.appender.ECELOG.layout.ConversionPattern=%d %5p [%t] %x (%c) %m%n
log4j.category.com.escenic=ERROR, ECELOG
log4j.category.neo=ERROR, ECELOG
log4j.additivity.neo=false
log4j.additivity.com.escenic=false

######################################################################
# The solr logging
log4j.appender.SOLR=org.apache.log4j.DailyRollingFileAppender
log4j.appender.SOLR.File=$escenic_log_dir/\${com.escenic.instance}-solr
log4j.appender.SOLR.layout=org.apache.log4j.PatternLayout
log4j.appender.SOLR.layout.ConversionPattern=%d %5p [%t] %x (%c) %m%n
log4j.category.org.apache.solr=INFO, SOLR
log4j.additivity.org.apache.solr=false

######################################################################
# Tomcat specific logging
log4j.appender.TOMCAT=org.apache.log4j.DailyRollingFileAppender
log4j.appender.TOMCAT.File=${escenic_log_dir}/\${com.escenic.instance}-tomcat
log4j.appender.TOMCAT.layout = org.apache.log4j.PatternLayout
log4j.appender.TOMCAT.layout.ConversionPattern = %d [%t] %-5p %c- %m%n

log4j.category.org.apache.catalina=INFO, TOMCAT
log4j.additivity.org.apache.catalina=false

######################################################################
# Get rid of the browser log which for some reason wanderse into the
# standard log4j log
log4j.appender.NOLOGGING=org.apache.log4j.varia.NullAppender
log4j.category.browser=FATAL, NOLOGGING
log4j.additivity.browser=false

EOF
  run cd $tomcat_base/lib/
  make_ln $common_nursery_dir/trace.properties
  run ln --symbolic --force trace.properties log4j.properties

  if [ $install_profile_number -eq $PROFILE_SEARCH_SERVER -o \
    $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    cat >> $common_nursery_dir/trace.properties <<EOF
EOF
  fi
}

## libraries needed for overriding the default logging framework in
## Tomcat.
function log4j_download_the_tomcat_juli_libraries_and_copy_these_to_cl() {
  log "Downloading Tomcat libraries to override java.util.Logging ..."
  local libraries="tomcat-juli-adapters.jar tomcat-juli.jar"
  local tomcat_base_uri=$(dirname $(get_tomcat_download_url))
  for el in $libraries; do
    download_uri_target_to_dir \
      $tomcat_base_uri/extras/$el \
      $download_dir
    local file=$download_dir/$(basename $el)
  done

  run cp $download_dir/tomcat-juli-adapters.jar $tomcat_home/lib/
  run cp $download_dir/tomcat-juli.jar $tomcat_home/bin/
  # we don't copy the log4j JAR as this is provided with ECE and EAE.
}

function log4j_ensure_java_util_logging_is_not_doing_anything() {
  log "Ensure java.util.Logging is put to rest ..."
  local file=$tomcat_base/conf/logging.properties
  if [ -e $file ]; then
    run rm $file
  else
    log $file "doesn't exist, strange"
  fi
}
