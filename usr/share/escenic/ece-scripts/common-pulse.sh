# by torstein@escenic.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 || source common-bashing.sh

pulse_bits="-\|/"

# Can be used like this:
# common_io_pulse_loaded 2>/dev/null || source common-pulse.sh
function common_pulse_is_loaded() {
  echo 1
}

function pulse() {
  echo -ne "\b${pulse_bits: i++ % ${#pulse_bits}: 1}"
}

### show_pulse
## $1 :: the PID of the process on which you want to view the pulse.
## $2 .. $n :: Strings to display while the pulse is running.
function show_pulse() {
  printne "${@: 2: $(( $# - 1 ))} ...."

  local pulse_pid=$1
  while true; do
    kill -0 $pulse_pid 2>/dev/null
    if [ $? -eq 0 ]; then
      pulse
      sleep 0.25
    else
      wait $pulse_pid
      local exit_code=$?
      if [ $exit_code -eq 0 ]; then
        echo -e '\b\E[37;32m'" \033[1mok\033[0m"
        tput sgr0
      else
        echo -e '\b\E[37;31m'" \033[1mfailed\033[0m"
        tput sgr0
        print "See $log for further details"
        log_call_stack

        # terminate the main ece script process.
        kill $$ 2>/dev/null
      fi

      break
    fi
  done
}
