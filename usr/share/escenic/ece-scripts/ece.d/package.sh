# creates DEB and RPM packages suitable for deploying any kind of ECE
# instance that was previously assembled.
function create_packages() {
  local ear=$cache_dir/engine.ear
  if [ ! -e $ear ]; then
    print_and_log "$ear does not exist." \
      "Did you run '"`basename $0`" -i" $instance "assemble'?"
    exit 1
  fi

  local dir=$(mktemp -d)
  local package_dir=$dir/debian
  local package_name=""
  
  if [ "$type" == "engine" ]; then
    package_name="escenic-content-engine-${instance}"
  elif [ "$type" == "search" ]; then
    package_name="escenic-search-engine-${instance}"
  elif [ "$type" == "rmi-hub" ]; then
    package_name="escenic-rmi-hub"
  elif [ "$type" == "analysis" ]; then
    package_name="escenic-analysis-engine-${instance}"
  fi
  
    # TODO the version might be a bit on the extreme side. Could come
    # from the SCM (if available)
  local version=$(date +%s)

  run mkdir -p $package_dir/DEBIAN
  cat > $package_dir/DEBIAN/control <<EOF
Package: $package_name
Version: $version
Section: base
Priority: optional
Architecture: all
Maintainer: Torstein Krause Johansen <torstein@escenic.com>
Description: The Escenic Content Engine of type ${type}
  for the ${instance} instance. Built on $HOSTNAME
EOF

  case $appserver in
    tomcat)
      local tomcat_base_dir=${package_dir}${tomcat_base}
      local tomcat_escenic_dir=${tomcat_base_dir}/escenic

            # lib
      run mkdir -p ${tomcat_escenic_dir}
      run cd ${tomcat_escenic_dir}
      run $java_home/bin/jar xf ${ear} lib

            # war
      run mkdir -p ${tomcat_base_dir}/webapps
      run cd ${tomcat_base_dir}/webapps
      for el in $($java_home/bin/jar tf ${ear} | grep .war$); do
        if [ -n "${deploy_webapp_white_list}" ]; then
          for ele in $deploy_webapp_white_list; do
            if [ ${el} == ${ele}.war ]; then
              run $java_home/bin/jar xf ${ear} ${el}
            fi
          done
        else
          run $java_home/bin/jar xf ${ear} ${el}
        fi
      done

            # putting this block here so that anything overridden in
            # tomcat_base takes precedence over tomcat_home
      if [ "${everything_but_the_kitchen_sink}" -eq 1 ]; then
        (
          local tomcat_home_dir=${package_dir}${tomcat_home}
          run mkdir -p ${tomcat_home_dir}
          run cd ${tomcat_home_dir}
          run cp -r ${tomcat_home}/{bin,lib} ${tomcat_home_dir}

          local etc_escenic_dir=${package_dir}${escenic_conf_dir}
          run mkdir -p ${etc_escenic_dir}
          cd ${etc_escenic_dir}
          run cp -r ${escenic_conf_dir}/{ece,ece-${instance}}.conf \
            ${etc_escenic_dir}

          run mkdir -p ${etc_escenic_dir}/engine
          run cp -r ${escenic_conf_dir}/engine/common \
            ${etc_escenic_dir}
          
          run mkdir -p ${etc_escenic_dir}/engine/instance
          run cp -r ${escenic_conf_dir}/engine/instance/${instance} \
            ${etc_escenic_dir}
        )
      fi
      
            # copy these from the current configuration: bin, conf
      run cp -r ${tomcat_base}/{bin,conf} ${tomcat_base_dir}

            # these just need to be there: logs, temp
      run mkdir ${tomcat_base_dir}/{logs,temp}

            # build the packages
      cd ${dir}
      run dpkg-deb --build debian
      local deb_package=${package_name}-${version}.deb
      run mv debian.deb ${deb_package}
      
      if [[ -x /usr/bin/alien && -x /usr/bin/fakeroot ]]; then
        run fakeroot alien --to-rpm --scripts ${deb_package}
        run mv *.rpm ${cache_dir}
        print "RPM package of your $instance $type instance with build"
        print "version $version is now available:"
        print $(echo ${cache_dir}/${package_name}-${version}*.rpm)
      fi
      
      mv *.deb ${cache_dir}
      print "DEB package of your $instance $type instance with with build"
      print "version $version is now available:"
      print ${cache_dir}/${deb_package}
      ;;
    *)
      print "Package creation is only supported on Tomcat so far."
      ;;
  esac

  run rm -rf ${dir}
}
