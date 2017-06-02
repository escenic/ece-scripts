# by torstein@escenic.com
function restart_type() {
  stop_type

    # sometimes the JVM refuses to shut down when doing a graceful
    # kill, therefore, if it's still running after the sleep above, we
    # use brute force to kill it.
  set_type_pid
  if [ -n "$type_pid" ]; then
    message="The $instance instance of $type failed to stop gracefully"
    print_and_log $message
    kill_type
  fi
  
  start_type
}
