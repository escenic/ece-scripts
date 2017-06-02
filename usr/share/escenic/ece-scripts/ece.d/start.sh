# by torstein@escenic.com

function start_type() {
  unset CLASSPATH
  export HOSTNAME
  message="Starting the $instance instance of $type on $HOSTNAME ..."
  print_and_log $message
  
  if [ "$type" == "rmi-hub" ]; then
    ensure_that_required_fields_are_set $hub_required_fields

    if [ -r $rmi_hub_conf ]; then
      export CLASSPATH=$rmi_hub_conf:$CLASSPATH
    else
      print $rmi_hub_conf "must point to a valid Nursery configuration" \
        "for the rmi-hub, you may copy the one found in" \
        "$ece_home/contrib/rmi-hub/config." \
        "Exiting :-("
      exit 1
    fi
    
    for el in $rmi_hub_home/lib/*.jar; do
      export CLASSPATH=$CLASSPATH:$el
    done

    $java_home/bin/java \
      -Djava.rmi.server.hostname=${ece_server_hostname} \
      neo.nursery.GlobalBus /Initial \
      1>>$log \
      2>>$log & pid=$!
    
    echo $pid > $pid_file
    exit 0
    
  elif [ "$type" == "search" ]; then
    # TODO trim & tun the default parameters for the search
    # instance.
    ensure_that_required_fields_are_set $engine_required_fields
  elif [ "$type" == "engine" ]; then
    ensure_that_required_fields_are_set $engine_required_fields
    if [ ! -d "$ece_security_configuration_dir" ] ; then
      print "ece_security_configuration_dir $ece_security_configuration_dir" \
        "did not exist." \
        "Exiting :-("
      exit 1
    fi
  elif [ "$type" == "analysis" ]; then
    ensure_that_required_fields_are_set $analysis_required_fields
  fi

  verify_that_directory_and_file_are_writeable $pid_file
  
  # indexer and engine are treated the same
  case $appserver in
    tomcat)
      # Tomcat respects JAVA_OPTS set in configure(), so no need to
      # set them here.
      if [ ! -x $tomcat_home/bin/catalina.sh ]; then
        print "$tomcat_home/bin/catalina.sh was not executable" \
          "unable to start tomcat"
        exit 1
      fi

      export CATALINA_PID=$pid_file
      export CATALINA_OUT=$(get_catalina_out_file)
      run $tomcat_home/bin/catalina.sh start
      ;;
    oc4j)
      export OC4J_JVM_ARGS=$ece_args
      $oc4j_home/bin/oc4j -start\
                1>>$log\
                2>>$log & pid=$!
      echo $pid > $pid_file
      ;;
    resin)
            # Resin has stared insisting on a -J prefix of the -D
            # prefixes :-) Tested with Resin 3.0.25
      resin_ece_args=`echo $ece_args | sed 's/-D/-J-D/g'`
      
            # works for Resin 3.0
      if [ -e $resin_home/bin/wrapper.pl ]; then
        exec perl $resin_home/bin/wrapper.pl \
          -chdir \
          -name httpd \
          -class com.caucho.server.resin.Resin \
          $resin_ece_args ${1+"$@"} \
          1>>$log \
          2>>$log & pid=$!
        echo $pid > $pid_file
      else
                # works for Resin 3.1
        $java_home/bin/java $ece_args \
          -jar $resin_home/lib/resin.jar \
          start \
          1>>$log \
          2>>$log & pid=$!
        echo $pid > $pid_file
      fi
      ;;
    jboss)
      $jboss_home/bin/run.sh \
        -b 0.0.0.0 \
        -c $jboss_conf \
        1>>$log \
        2>>$log & pid=$!
      echo $pid > $pid_file
      ;;
    *)
      echo "" # extra line feed, because of the echo -n above
      print "No appserver is defined in $ece_conf"
      exit 1
  esac
  
  exit_on_error $message
}
