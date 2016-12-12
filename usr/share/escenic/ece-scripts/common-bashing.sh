#! /usr/bin/env bash

# Common, useful methods for BASH scripts. The callee is responsible
# for setting the following variables:
#
# * pid_file
# * log
#
# by tkj@vizrt.com

debug=0

# basename $0 will resolve to the file name of the calling script,
# not common-bashing itself.
lock_file=/var/run/escenic/$(basename $0 .sh).lock

# Same comment as for the lock file :-)
pid_file=/var/run/escenic/$(basename $0 .sh).pid

function common_bashing_is_loaded() {
  echo 1
}

### get_seconds_since_start
## Returns the seconds since the command was started
function get_seconds_since_start() {
  local seconds="n/a"

  if [ -n "$pid_file" -a -r "$pid_file" ]; then
    now=`date +%s`
    started=`stat -c %Y $pid_file`
    seconds=$(( now - started ))
  fi

  echo "$seconds"
}

### get_id
## Returns the ID string to be printed in the prompt from this
## command.
function get_id() {
  if [ -n "$id" ]; then
    echo $id
    return
  fi

  local timestamp=$(get_seconds_since_start)
  echo "[$(basename $0)-${timestamp}]"
}

### debug
## Your code can call this method to print debug messages if the debug
## flag has been turned on (debug=1).
##
## $@ :: as many strings as you want
function debug() {
  if [ $debug -eq 1 ]; then
    echo "[$(basename $0)-debug]" "$@"
  fi
}

### print
## Output your messgae with command ID prompt.
##
## $@ :: as many strings as you want
function print() {
  if [[ "$quiet" == 1 ]]; then
    echo $@ | fmt
    return
  fi

  # we break the text early to have space for the ID.
  local id="$(get_id) "
  local text_width=$(( 80 - $(echo $id | wc -c) ))
  echo $@ | fmt -w $text_width | sed "s~^~${id}~g"
}

function printne() {
  echo -ne $(get_id) $@
}

### log
## Will log all messages past to it.
##
## - If the parent directory of the log file doesn't exist, the method
## will try to create it.
##
## - If the log file doesn't exist, the method will try to create it.
##
## $@ :: list of strings
function log() {
  if [ -z $log ]; then
    return
  fi

  # cannot use run wrapper her, it'll trigger an eternal loop.
  fail_safe_run mkdir -p $(dirname $log)
  fail_safe_run touch $log
  echo $(get_id) $@ >> $log
}

### print_and_log
## Write input both to standard out with proper prompt & wrapping +
## log the same message without wrapping.
##
## $@ :: list of strings
function print_and_log() {
  print "$@"
  log "$@"
}

### log_call_stack
## Logs the stack trace/call tree of the last error. This works pretty
## much exactly like stack traces in Java.
function log_call_stack() {
  log "Call stack (top most is the last one, main is the first):"

  # skipping i=0 as this is log_call_stack itself
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    echo -n  ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]}:${FUNCNAME[$i]}"()" >> $log
    if [ -e ${BASH_SOURCE[$i]} ]; then
      echo -n " => " >> $log
      sed -n "${BASH_LINENO[$i-1]}p" ${BASH_SOURCE[$i]} | \
        sed "s#^[ \t]*##g" >> $log
    else
      echo "" >> $log
    fi
  done
}

### remove_pid_and_exit_in_error
## Remove the command PID, log a stack trace and then exit the command
## in error ($? -ne 0).
function remove_pid_and_exit_in_error() {
  if [[ -z $pid_file && -e $pid_file ]]; then
    rm $pid_file
  fi

  # this method is also used from bootstrapping methods in scripts
  # where the log file may not yet exist, hence, we test for its
  # existence here before logging the call/stack trace.
  if [ -w $log ]; then
    log_call_stack
  fi

  kill $$
}

### exit_on_error
## Will exit in error if, and only if, the last command was
## unsuccessful.
function exit_on_error() {
  local code=$?
  if [ ${code} -gt 0 ]; then
    print_and_log "The command <${@}> run as user $USER $(red FAILED)" \
      "(the command exited with code ${code}), I'll exit now :-("
    print "See $log for further details."
    remove_file_if_exists $lock_file
    remove_pid_and_exit_in_error
  fi
}

### run
## Runs the passed command & arguments and log both standard error and
## standard out. If the command exits cleanly, the calling code will
## continue, however, if the commadn you passed to run failed, the run
## wrapper will log the call stack and exit in error.
##
## $@ :: list of strings making up your command. Everything except
##       pipes can be bassed
function run() {
  if [ ! -e $log ]; then
    touch $log || {
      echo "Couldn't create $log"
      kill $BASHPID
    }
  fi

  debug "${FUNCNAME}()" → "$@"
  "${@}" 1>>$log 2>>$log
  exit_on_error $@
}

### fail_safe_run
## Same as run, but will not fail if logging fails.
##
## $@ :: list of strings making up your command. Everything except
##       pipes can be bassed.
function fail_safe_run() {
  "${@}"
  if [ $? -gt 0 ]; then
    echo $(basename $0) $(red FAILED) "executing the command [$@]" \
      "as user" ${USER}"." \
      $(basename $0) "will now exit." | \
      fmt
    exit 1
  fi
}

### is_number
## Returns 1 if the passed argument is a number, 0 if not.
##
## $1: the value you wish to test.
function is_number() {
  for (( i = 0; i < ${#1}; i++ )); do
    if [ $(echo ${1:$i:1} | grep [0-9] | wc -l) -lt 1 ]; then
      echo 0
      return
    fi
  done

  echo 1
}

### get_escaped_bash_string
## Returns an escaped string useful for sed and other BASH commands.
##
## $1 :: the string
function get_escaped_bash_string() {
  local result=$(echo $1 | \
    sed -e 's/\$/\\$/g' \
    -e 's/\*/\\*/g' \
    -e 's#/#\\/#g' \
    -e 's/\./\\./g')
  echo $result
}

### get_perl_escaped
## Munin nodes need the IP of the munin gatherer to be escaped. Hence
## this function.
##
## $1 :: the IP
function get_perl_escaped() {
  local escaped_input=$(
    echo $1 | sed 's/\./\\./g'
  )
  echo "^${escaped_input}$"
}

### red
## Returns the inputted string(s) as red
##
## $1 :: input string
function red() {
  if [[ -t "0" || -p /dev/stdin ]]; then
    echo -e "\E[37;31m\033[1m${@}\033[0m"
  else
    echo "$@"
  fi
}

### green
## Returns the inputted string(s) as green
##
## $1 :: input string
function green() {
  if [[ -t "0" || -p /dev/stdin ]]; then
    echo -e "\E[37;32m\033[1m${@}\033[0m"
  else
    echo "$@"
  fi
}

### yellow
## Returns the inputted string(s) as yellow
##
## $1 :: input string
function yellow() {
  if [[ -t "0" || -p /dev/stdin ]]; then
    echo -e "\E[37;33m\033[1m${@}\033[0m"
  else
    echo "$@"
  fi
}

### blue
## Returns the inputted string(s) as blue
##
## $1 :: input string
function blue() {
  if [[ -t "0" || -p /dev/stdin ]]; then
    echo -e "\E[37;34m\033[1m${@}\033[0m";
  else
    echo "$@"
  fi
}

### get_base_dir_from_bundle
## Allows you to peek inside any archive to see which base directory
## that archive will produce once extracted.
##
## $1: full path to the file.
function get_base_dir_from_bundle() {
    local file_name=$(basename $1)
    suffix=${file_name##*.}

    if [ ${suffix} = "zip" ]; then
        # we'll look inside the archive to determine the base_dir
        file_name=$(
            unzip -t $1 2>>$log | \
                awk '{print $2}' | \
                cut -d'/' -f1 | \
                sort | \
                uniq | \
                grep -v errors | \
                grep [a-z]
        )
    else
        for el in .tar.gz .tar.bz2 .zip; do
            file_name=${file_name%$el}
        done
    fi

    echo $file_name
}

### ensure_variable_is_set
## Will assert that all the passed variable names are set, if not, it
## Requires $conf_file to be set.  will exit in error.
##
## $@ :: a list of variable names
function ensure_variable_is_set() {
  local requirements_failed=0

  for el in $@; do
    if [ -n "$(eval echo $`echo $el`)" ]; then
      continue
    fi

    print_and_log "You need to specifiy '$el' in $conf_file"
    requirements_failed=1
  done

  if [ $requirements_failed -eq 1 ]; then
    remove_pid_and_exit_in_error
  fi
}

### is_archive_healthy
## $1 :: the archive to check, must be a local file
function is_archive_healthy() {
  if [[ "$1" == *".ear" || "$1" == *".zip" || "$1" == *".jar" ]]; then
    unzip -t $1 2>/dev/null 1>/dev/null
  elif [[ "$1" == *".tar.gz" ]]; then
    tar tzf $1 2>&1 > /dev/null
  else
    echo 0
    return
  fi

  if [ $? -eq 0 ]; then
    echo 1
  else
    echo 0
  fi
}

### extract_archive
## Extracts any of the following archives: tar.gz, tgz, zip, tar.bz2
##
## $1 :: the archive
## $2 :: optionally, the target directory
function extract_archive() {
  if [[ "$1" == *".tar.gz" || "$1" == *".tgz" ]]; then
    if [[ -n "$2" && -d "$2" ]]; then
      run tar xzf $1 -C $2
    else
      run tar xzf $1
    fi
  elif [[ "$1" == *".tar.bz2" ]]; then
    if [[ -n "$2" && -d "$2" ]]; then
      run tar xjf $1 -C $2
    else
      run tar xjf $1
    fi
  elif [[ "$1" == *".zip" || "$1" == *".ear" ]]; then
    if [[ -n "$2" && -d "$2" ]]; then
      run unzip -q $1 -d $2
    else
      run unzip -q $1
    fi
  else
    print_and_log "Don't know how to extract $1"
    exit 1
  fi
}

# the next steps printed when the user has installed his/her
# components.
next_steps=()

## Adds a next step for the user to do after finishing running your
## command.
##
## $1 :: your added line
function add_next_step() {
  next_steps[${#next_steps[@]}]="$@"
  return

  if [ -n "$next_steps" ]; then
    next_steps=${next_steps}$'\n'"[$(basename $0)] "${1}
  else
    next_steps="[$(basename $0)] $@"
  fi
}

function print_next_step_list() {
  for (( i = 0; i < ${#next_steps[@]}; i++ )); do
    print "  - " ${next_steps[$i]}
  done
}

### is_unauthorized_to_access_url
## Method will return 1 if the user/pass is unauthorized to access the
## URL in question. Hence, a 0 means that the user CAN access the URL.
##
## $1 :: user
## $2 :: pass
## $3 :: URL
function is_unauthorized_to_access_url() {
  curl --silent --connect-timeout 20 --head  --user ${1}:${2} ${3} | \
    head -1 | \
    grep "401 Unauthorized" | \
    wc -l
}

### is_authorized_to_access_url
## Will return 1 if the user can access the URL.
##
## $1 :: user
## $2 :: pass
## $3 :: URL
function is_authorized_to_access_url() {
  curl --silent --connect-timeout 20 --head --user ${1}:${2} ${3} | \
    head -1 | \
    grep "200 OK" | \
    wc -l
}

### ltrim
## $1 :: the string to which you want to remove any leading white
##       spaces.
function ltrim() {
  echo $1 | sed 's/^[ ]*//g'
}

### split_string
## Splits a string based on a delimter, just like you're used to from
## Python, Java++
##
## $1    :: the character on to wich to split it
## $2 .. $n :: the rest of the arguments is the string(s) to split.
function split_string() {
  if [[ -z $1 || -z $2 ]]; then
    return
  fi

  local delimeter=$1
  shift;

  local old_ifs=$IFS
  IFS=$delimeter
  read splitted_string <<< $@
  IFS=$old_ifs

  echo $splitted_string
}

### create_file_if_doesnt_exist
## Creates $1 file if possible
##
## $1 :: the file, typically a PID or lock file.
function create_file_if_doesnt_exist() {
  if [ -z $1 ]; then
    return
  elif [ -e $1 ]; then
    return
  fi

  local dir=$(dirname $1)

  # since this method can be called really early in scripts, we cannot
  # use the run wrapper here.
  fail_safe_run mkdir -p $(dirname $1)
  fail_safe_run touch $1
}

### remove_file_if_exists
##
## $1 :: the file
function remove_file_if_exists() {
  if [ -z $1 ]; then
    return
  elif [ ! -e $1 ]; then
    return
  fi

  fail_safe_run rm $1
}

### create_lock
## Will create a lock (and the lock's directory) for the caller. If
## the lock already exists, this function will NOT cause your program
## to fail. If you want to it to fail, use create_lock_or_fail
## instead.
##
## $1 :: the lock file
function create_lock() {
  if [ -e $lock_file ]; then
    print_and_log $lock_file "exists, I'll exit"
    exit 0
  else
    fail_safe_run mkdir -p $(dirname $lock_file)
    fail_safe_run touch $lock_file
  fi
}

### create_lock_or_fail
## Does the same as create_lock with the difference that it will make
## your program fail if the lock already exists and it will print the
## error to standard out as well as in the log.
##
## $1 :: the lock file
function create_lock_or_fail() {
  if [ -e $lock_file ]; then
    print_and_log $lock_file "exists, I'll exit"
    exit 1
  else
    fail_safe_run mkdir -p $(dirname $lock_file)
    fail_safe_run touch $lock_file
  fi
}

### remove_lock
function remove_lock() {
  if [ ! -e $lock_file ]; then
    return
  fi

  fail_safe_run rm $lock_file
}

### create_pid
function create_pid() {
  fail_safe_run mkdir -p $(dirname $pid_file)
  echo $$ > $pid_file
}

### remove_pid
function remove_pid() {
  if [ -e $pid_file ]; then
    fail_safe_run rm $pid_file
  fi
}

### common_bashing_exit_hook
## To make your script call this whenever it does a controlled exit,
## either by running through the script, call this hook.
##
## Put this line at the start of your script:
##
## trap common_bashing_exit_hook EXIT
##
## $@ :: signal
function common_bashing_exit_hook() {
  remove_pid
  remove_lock
  kill $$
}

### common_bashing_user_cancelled_hook
## Put this in your script to have it exit whenever the user hits the
## user pressing Ctrl+c or by someone sending a regular kill <PID>
## signal to it.
##
## Usage:
## trap common_bashing_user_cancelled_hook SIGHUP SIGINT
##
## $@ :: signal
function common_bashing_user_cancelled_hook() {
  print "User cancelled $(basename $0), cleaning up after me ..."
  common_bashing_exit_hook
}

### lowercase
## Returns the string passed where all letters are lower cased.
##
## $@ :: as many strings as you like.
function lowercase() {
  echo "$@" | tr [A-Z] [a-z]
}

### pretty_print_xml
## Pretty prints the passed XML file
##
## $1 :: xml file
function pretty_print_xml() {
  local file=$1
  local tmp_file=
  tmp_file=$(mktemp)

  xmllint --format "${file}" > "${tmp_file}"
  run mv "${tmp_file}" "${file}"
}
