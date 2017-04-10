# Emacs: -*- mode: sh; sh-shell: bash; -*-

# Module for the 'ece deploy' command.

function get_state_file() {
  echo $data_dir/${instance}.state
}

function get_deployment_log_file() {
  echo $data_dir/${instance}-deployment.log
}

## $1 : local EAR file
function get_version_from_ear_file() {
  local version=$(basename $1 .ear | sed 's/^engine-//g')

  # if this is emtpy, it means it was called just engine.ear, in which
  # case we generate a nice version string.
  if [[ -z "$version" || "$version" == "engine" ]]; then
    version=$(date +%Y%m%d.%H%M)
  fi

  echo $version
}

## $1 : local EAR file
function update_deployment_state_and_log_files() {
  local state_file=$(get_state_file)

  if [ ! -w $(dirname $state_file) ]; then
    print_and_log "I cannot write to $(dirname state_file), I will exit :-("
    exit 1
  fi

  if [ -n "${file}" ]; then
    ear_used=$file
  else
    ear_used=$1
  fi

  local deployment_date=$(date)
  # we use $1 here as this is the locally downloaded EAR (if the
  # deployment was done with --uri)
  local ear_md5_sum=$(md5sum $1 | cut -d' ' -f1)

  cat > $state_file <<EOF
ear_used=$ear_used
version=$(get_version_from_ear_file ${ear_used})
md5_sum=${ear_md5_sum}
deployed_date=${deployment_date}
EOF

  print_and_log "Deployment state file updated: $state_file"

  # update the deployment log too
  echo ${deployment_date} \
    $(basename ${ear_used}) \
    ${ear_md5_sum} \
    >> $(get_deployment_log_file)

  print_and_log "Deployment log file updated:" $(get_deployment_log_file)
}

## Finds the ECE webapps directory with webservice.war++
##
## If there are more than one ECE package installed, the latest is
## picked. This, however, will (probably) never happens since the ECE
## packages have conflict markers in place to prevent having multiple
## ECE installed (which will be a problem since they all contain some
## of the same files, especially in /etc/escenic).
function _find_ece_webapps_dir() {
  find -L /usr/share/escenic/escenic-content-engine-* \
       -maxdepth 1 \
       -name webapps \
       -type d |
    tail -n 1
}

function _create_engine_bootstrap_jar_in_dir() {
  local dir=$1
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local -a layers=(
    family
    vosa
    common
    host
    addon
    default
    instance
    server
    environment
  )

  local bootstrap_dir="${tmp_dir}/com/escenic/configuration/bootstrap"
  local layers_dir="${bootstrap_dir}/layers"
  for layer in "${layers[@]}"; do
    local layer_dir="${layers_dir}/${layer}"
    mkdir -p "${layer_dir}"
    cat > "${layer_dir}/Layer.properties" <<'EOF'
$class=neo.nursery.PropertyFileConfigurator
depot=./Files
EOF
  done

  cat > "${layers_dir}/family/Files.properties" <<'EOF'
# The family configuration is read from the file system hierarchy standard for configuration
$class=neo.nursery.FileSystemDepot

# The files are loaded from a subdirectory of /etc/escenic/engine/host
# either from the system property "com.escenic.config.engine.family"
# or the family name "default" if that system property is null
fileSystemRoot = /etc/escenic/engine/family/${com.escenic.config.engine.family "default"}
EOF
  cat > "${layers_dir}/vosa/Files.properties" <<'EOF'
$class=neo.nursery.FileSystemDepot
fileSystemRoot = /etc/escenic/engine/vosa/
EOF
  cat > "${layers_dir}/common/Files.properties" <<'EOF'
# The common configuration is read from the file system hierarchy standard location for configuration files
$class=neo.nursery.FileSystemDepot
fileSystemRoot = /etc/escenic/engine/common/

EOF
  cat > "${layers_dir}/host/Files.properties" <<'EOF'
# The host configuration is read from the file system hierarchy standard for configuration
$class=neo.nursery.FileSystemDepot

# The files are loaded from a subdirectory of /etc/escenic/engine/host
#   * the system property "hostname" if specified
#   * the environment variable "HOSTNAME" or "COMPUTERNAME"
#   otherwise the default value of "localhost"
fileSystemRoot = /etc/escenic/engine/host/${hostname env:HOSTNAME env:COMPUTERNAME "localhost"}/
EOF

  cat > "${layers_dir}/addon/Files.properties" <<'EOF'
# The addon configuration is read from the classpath with no prefix
$class=neo.nursery.ResourceDepot
EOF
  cat > "${layers_dir}/default/Files.properties" <<'EOF'
# The Escenic default configuration is read from the classpath with a prefix of com/escenic/configuration/default
$class=neo.nursery.ResourceDepot
prefix=com/escenic/configuration/default
EOF
  cat > "${layers_dir}/instance/Files.properties" <<'EOF'
$class=neo.nursery.FileSystemDepot
fileSystemRoot = /etc/escenic/engine/instance/${com.escenic.instance "default"}
EOF
  cat > "${layers_dir}/server/Files.properties" <<'EOF'
# The host configuration is read from the file system hierarchy
# standard for configuration
$class=neo.nursery.FileSystemDepot

# The files are loaded from a subdirectory of /etc/escenic/engine/host-instance
# named after the hostname and instance name it's running as.
fileSystemRoot = /etc/escenic/engine/server/${escenic.server "default"}/

EOF
  cat > "${layers_dir}/environment/Files.properties" <<'EOF'
$class=neo.nursery.FileSystemDepot
fileSystemRoot = /etc/escenic/engine/environment/${com.escenic.environment "unknown"}/
EOF

  cat > "${bootstrap_dir}/Nursery.properties" <<'EOF'
########################################################
# Site Wide Nursery configuration file.
########################################################
# The purpose of this file is to set up the nursery,
# and all of the other configuration layers that are
# to be used by this configuration.
#
# This Nursery component will bootstrap the Nursery.
#
# Therefore, it is vital that all files needed to
# configure the nursery are available in _this_
# configuration layer.
#
# Only after loading the Nursery component, will the
# other configuration layers be visible to any other
# Nursery component.
#
# After bootstrapping itself, it will  turn bootstrap
# the rest of Escenic.
#
# It is possible to do System property substitution
# in all configuration layers, even this configuration
# layer:
#   someProperty=${some.system.property}
# will expand to the value of the system property
# called "some.system.property".
#
# Note: There is only one nursery per Java process.
########################################################

$class=neo.nursery.Bootstrapper

########################################################
# CONFIGURATION LAYERS
########################################################
# Each referenced component must have its own
# properties file; they _must_ reside in this
# configuration layer.
#
# Content Engine ships with three default layers
# layer.01 = /layers/default/Layer
# layer.02 = /layers/addon/Layer
# layer.03 = /layers/common/Layer
########################################################

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

# Customer :: "escenic.server" specific layer
layer.09 = /layers/server/Layer
EOF

  jar cf "${dir}/engine-bootstrap-config.jar" -C "${tmp_dir}" .
  rm -r "${tmp_dir}"
}

## Assumes the variable ear is set (with the EAR to be deployed).
##
## If the file in 'ear' doesn't exist, the method will create a
## default EAR.
##
## Finally, the method will update the ear global variable with that
## of the newly created EAR.
function _if_no_ear_try_to_create_a_default_one() {
  if [ -e "${ear}" ]; then
    return
  fi

  local ece_webapps_dir=
  ece_webapps_dir=$(_find_ece_webapps_dir)

  if [ ! -d "${ece_webapps_dir}" ]; then
    return
  fi

  print_and_log "${ear} doesn't exist, will create a default,
    minimal EAR based on ${ece_webapps_dir//\/webapps}"
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}"/{jar,ear/lib}

  # lib
  run cp "${ece_webapps_dir}/../lib/"*.jar "${tmp_dir}/ear/lib"

  # war
  if [ "${type}" == engine ]; then
    _create_engine_bootstrap_jar_in_dir "${tmp_dir}/ear/lib"
  fi
  run cp "${ece_webapps_dir}/"*.war "${tmp_dir}"/ear

  local ear_fn=
  ear_fn="${cache_dir}/minimal-$(date +%s).ear"
  jar cf "${ear_fn}" -C "${tmp_dir}/ear" .
  chmod -R 755 "${tmp_dir}"

  ear=${ear_fn}
}

function deploy() {
  local ear=$cache_dir/engine.ear

  if [ -n "$file" ]; then
    print_and_log "Deploying $file on $instance ..."

    #Check if the file is a cached file, then will just install the file.
    ear=$cache_dir/$(basename $file)
    if [ -e "$ear" ] && [ $(is_archive_healthy $ear) -eq 1 ]; then
      print_and_log "I found a healthy $ear locally so I will not try to fetch it (again)."
    elif [ -f "$file" ]; then
      print_and_log " Found a local ear file $file"
      log "Copying it to to $cache_dir"
      run cp "${file}" "${cache_dir}"
    else
      # wget_auth is needed for download_uri_target_to_dir
      wget_auth=$wget_builder_auth
      download_uri_target_to_dir $file $cache_dir
    fi

    if [ ! -e "$ear" ]; then
      print_and_log "The EAR $ear_uri specified in $file could" \
        "not be retrieved. I will exit now. :-("
      exit 1
    fi
  else
    _if_no_ear_try_to_create_a_default_one "${ear}"
  fi

  if [ ! -e "$ear" ]; then
    print_and_log "$ear does not exist. " \
      "Did you run '"`basename $0`" -i" $instance "assemble'?"
    exit 1
  fi

  if [ $(is_archive_healthy $ear) -eq 0 ]; then
    print_and_log "$ear is faulty, I cannot deploy it :-("
    exit 1
  fi

  # extract EAR to a temporary area
  local dir=$(mktemp -d)
  (
    run mkdir -p $dir
    run cd $dir
    run unzip -q $ear < /dev/null
  )

  print "Deploying $ear on ${instance} (${appserver}) ..."

  case $appserver in
    tomcat)
      # We do not want the Escenic jars to share the same classloader
      # folder as tomcat does We thereby want clients to use a
      # separate escenic classloader to avoid strange upgrade problems
      # i.e wrong versions of certain libraries.
      if [ -d $tomcat_base/escenic/lib ]; then
        if [ `ls $tomcat_base/escenic/lib | grep .jar | wc -l` -gt 0 ]; then
          run rm $tomcat_base/escenic/lib/*.jar
        fi
        run cp $dir/lib/*.jar $tomcat_base/escenic/lib
        remove_unwanted_libraries $tomcat_base/escenic/lib
      else
        print "Could not find $tomcat_base/escenic/lib. Exiting."
        print "Also make sure that you have defined this directory in"
        print "  $tomcat_base/conf/catalina.properties"
        print "see sample configuration in the engine distribution"
        print "  contrib/appserver/tomcat/catalina-sample.properties"
        exit 1
      fi

      run rm -rf $tomcat_base/work/*

      # this scenario is likely when running many minimal instances of
      # tomcat and some of these are not properly initialised.
      if [ ! -d $tomcat_base/webapps ]; then
        print $tomcat_base/webapps "doesn't exist, exiting."
        exit 1
      fi

      if [ -n "$deploy_webapp_white_list" ]; then
        deploy_this_war=0
        print_and_log "Deployment white list active, only deploying: " \
          $deploy_webapp_white_list
      fi

      for war in $dir/*.war ; do
        local app_base=$(get_app_base $war)
        local name=$(basename $war .war)

        local deploy_this_war=1
        if [ -n "$publications_webapps" ]; then
         for el in $publications_webapps; do
           OIFS=$IFS
           IFS=':' read publication webapps <<< "$el"
           IFS=','
           for webapp in $webapps; do
              if [ "$webapp" == "$name" ]; then
                deploy_this_war=0
                deploy_war $tomcat_base/webapps-${publication}/$name $war
                break
              fi
           done
           IFS=$OIFS
        done
      fi
        if [ -n "$deploy_webapp_white_list" ]; then
          local deploy_this_war=0

          for el in $deploy_webapp_white_list; do
            if [[ "$el" == "$name" ]]; then
              log "found $war in white list, will deploy it"
              local deploy_this_war=1
            fi
          done
        fi

        if [ "$deploy_this_war" -eq 0 ]; then
          continue
        fi

        deploy_war $tomcat_base/$app_base/$name $war
        if [ ${enable_memcached_support-1} -eq 1 ]; then
          add_memcached_support $tomcat_base/$app_base/$name
        fi
      done

      if [ $type == "search" ]; then
        if [[ -L $tomcat_base/webapps/indexer-webapp-presentation && \
              -d $tomcat_base/webapps/indexer-webapp-presentation ]]; then
            print_and_log "Found $tomcat_base/webapps/indexer-webapp-presentation so deleting it"
            run rm -rf $tomcat_base/webapps/indexer-webapp-presentation
        fi
        run cd $tomcat_base/webapps/
        run ln -s indexer-webapp indexer-webapp-presentation
      fi
      ;;

    resin)
      if [ ! -d $resin_home/deploy ]; then
        mkdir -p $resin_home/deploy \
          1>>$log \
          2>>$log
      fi
      cp $ear $resin_home/deploy \
        1>>$log \
        2>>$log
      ;;
    *)
      print "Deployment is only implemented for Resin and Tomcat so far."
      ;;
  esac

  run rm -rf ${dir}
  update_deployment_state_and_log_files $ear
}
## $1: webapp directory
## $2: war file name
function deploy_war() {
  local app_dir=$1
  local war_file=$2
  if [ -d $app_dir ] ; then
    run rm -rf $app_dir
  fi
  make_dir $app_dir
  run cd $app_dir
  run unzip -q $war_file < /dev/null
}

## $1 : dir of the webapp
function add_memcached_support() {
  if [[ "$do_not_add_memcached_support" == "1" ]]; then
    return
  fi

  if [ ! -d "$1" ]; then
    log $1 "doesn't exist"
    return
  fi

  local exempt_from_memcached_list="
      escenic
      escenic-admin
      indexer-webapp studio
      indexer-webservice
      inpage-ws dashboard
    "

  for el in $exempt_from_memcached_list; do
    if [[ $(basename $1) == "$el" ]]; then
      return
    fi
  done

  log "Adding memcached support in $1 ..."
  local dir=$1/WEB-INF/localconfig/neo/xredsys/presentation/cache
  run mkdir -p $dir
  local file=$dir/PresentationArticleCache.properties

  if [[ -e $file && $(grep "\$class" $file | wc -l) -gt 0 ]]; then
    sed -i "s#\$class=.*#\$class=neo.util.cache.Memcached#g" $file
  else
    echo "\$class=neo.util.cache.Memcached" >> $file
  fi

  exit_on_error "sed on $file"
}

## Removes unwanted JARs. e.g. if type=search, we remove the
## engine-config.jar
##
## $1 :: the directory to check
function remove_unwanted_libraries() {
  if [ ! $1 ]; then
    return
  elif [ ! -d $1 ]; then
    return
  elif [ $type != "search" ]; then
    return
  fi

  log "Removing $1/engine-config-*.jar since this is a search instance"
  run find "${1}/." -maxdepth 1 -name "engine-config-*.jar" -delete
}
