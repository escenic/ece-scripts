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

function deploy() {
  local ear=$cache_dir/engine.ear

  if [ -n "$file" ]; then
    print_and_log "Deploying $file on $instance ..."

    #Check if the file is a cached file, then will just install the file.
    # If it is not cached and a local file then create a symlink of that file in cache directory otherwise
    #We we wil consider it is a url and will try to download the file.
    ear=$cache_dir/$(basename $file)
    if [ -e "$ear" ] && [ $(is_archive_healthy $ear) -eq 1 ]; then
      print_and_log "If found a healthy $ear locally so I will not fetch it again."
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

  print "Deploying $ear on $appserver ..."

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
  run rm $1/engine-config-*.jar
}
