# by torstein@escenic.com
function kill_type() {
  if [ -n "$type_pid" ]; then
    message="Using force to stop the $instance instance of $type on $HOSTNAME ..."
    log $message
    print $message
    kill -9 $type_pid
    if [ -w $pid_file ]; then
      rm $pid_file
    fi
  else
    print "No $instance instance of $type on $HOSTNAME to be killed"
  fi
  
  exit_on_error "kill_type"
}
