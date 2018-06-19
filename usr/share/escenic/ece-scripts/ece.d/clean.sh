function clean_up() {
  if [[ "$type" == "engine" && -e "$assemblytool_home/build.xml" ]]; then
    print "Cleaning up generated files in $assemblytool_home ..." 
    run cd $assemblytool_home
    run ant clean
  fi

  if [[ $appserver == "tomcat" ]]; then
    local dir_list="
      $tomcat_base/work
      $tomcat_base/temp
    "
    for el in $dir_list; do
      if [ -d $el ]; then
        print "Cleaning up ${instance}'s $(basename $el) directory in $el ..."
        run rm -rf $el/*
      fi
    done
  fi

  print "Cleaning up EARs in ${cache_dir} ..."
  find  "${cache_dir}" -name "*.ear" -delete 2>/dev/null
}
