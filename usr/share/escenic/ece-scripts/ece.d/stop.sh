# by torstein@escenic.com
function stop_type() {
  local message="Stopping the $instance instance of $type on $HOSTNAME ..."

  if [ -n "$type_pid" ]; then
    log $message
    print $message

    if [ -r $pid_file ]; then
      if [ "$type_pid" != "`cat $pid_file`" ]; then
        print "Is running, but was not started with `basename $0`"
        print "system PID $ece_pid differs from the PID in $pid_file"
        print "removing dangling PID file $pid_file. "
        print "In future, be sure to use $0 to start "
        print "and stop your $type"
        run kill $type_pid
        rm $pid_file
        return
      fi
    fi

    for i in {0..15}; do
      set_type_pid
      
      if [ -n "$type_pid" ]; then
        run kill $type_pid
      else
        debug "Previous gracious kill attempt of $instance succeeded."
        break
      fi
      
      sleep 1
    done

    set_type_pid
    if [ -n "$type_pid" ]; then
      print_and_log "I could not stop $type instance $instance gracefully," \
        "I will now use force."
      run kill -9 $type_pid
    fi

    hang_around_to_see_that_forceful_kill_succeeded
    
    if [ -e $pid_file ]; then
      run rm $pid_file
    fi
  else
    print "The $instance instance of $type on $HOSTNAME is NOT running"
  fi
  
  exit_on_error $message
}

function hang_around_to_see_that_forceful_kill_succeeded() {
  # sometimes, kill -9 *might* take some time before it
  # returns. Hence, we hang around for a couple of seconds.
  for i in {0..5}; do
    set_type_pid
    
    if [ -n "$type_pid" ]; then
      sleep 1
    else
      debug "Previous forceful kill attempt of $instance succeeded."
      break
    fi
  done
  
  set_type_pid
  if [ -n "$type_pid" ]; then
    print_and_log "I was not able to forcefully kill PID $type_pid" \
      "something is very wrong here :-("
    return
  fi
}  
