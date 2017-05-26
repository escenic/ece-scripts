#! /usr/bin/env bash

# by torstein@escenic.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 || source common-bashing.sh

# Can be used like this:
# common_io_is_loaded 2>/dev/null || source common-io.sh
function common_io_is_loaded() {
  echo 1
}

### set_conf_file_value
##
## $1 :: is the property
## $2 ... :: to the (last - 1) is the value
## $n -1 :: The last argument is the file
function set_conf_file_value() {
  if [ $# -lt 3 ]; then
    return
  fi

  local file=${@:${#@}}
  local key=${@:1:1}
  local value_end_index=$(( $# - 2 ))
  local value=${@:2:${value_end_index}}

  local parent_dir=$(dirname $file)
  if [ ! -d ${parent_dir} ]; then
    print ${parent_dir} "doesn't exist, something is wrong :-("
    remove_pid_and_exit_in_error
  fi

  if [ -r $file ]; then
    if [ $(grep ^$1 $file | wc -l) -gt 0 ]; then
      if [ ${dont_quote_conf_values-0} -eq 0 ]; then
        sed -i "s~$key=.*~$key=\"$value\"~g" $file
      else
        sed -i "s~$key=.*~$key=$value~g" $file
      fi
    else
      if [ $dont_quote_conf_values -eq 0 ]; then
        echo "$key=\"$value\"" >> $file
      else
        echo "$key=$value" >> $file
      fi

    fi
  else
    if [ $dont_quote_conf_values -eq 0 ]; then
      echo "$key=\"$value\"" >> $file
    else
      echo "$key=$value" >> $file
    fi
  fi
}

### make_dir
## Will create the directory/directories if they don't already
## exist. If the calling user doesn't have access rights to create the
## directory(ies), this function will make your script fail.
##
## $@ :: a list of directories
function make_dir() {
  for el in $@; do
    if [ ! -d $el ]; then
      run mkdir -p $el
    fi
  done
}

### remove_dir
## Will remove the directory if it exists. Safe to call if the
## directory doesn't exist.
##
## $1 :: the dir
function remove_dir() {
  if [ -d $1 ]; then
    run rmdir $1
  fi
}

### make_ln
## Will create the symbolic, if the target exists. If not, the command
## will make your command exist in error.
##
## $1 :: target (or, if $2 is specified, $1 is the source)
## $2 :: the target, optional.
function make_ln() {
  if [ $2 ]; then
    if [ -e $1 -a ! -h $2 ]; then
      run ln -s $1 $2
    elif [ ! -e $1 ]; then
      print_and_log "Tried to make a symlink to $1, but it doesn't exist"
      remove_pid_and_exit_in_error
    fi
  else
    if [ -e $1 -a ! -h $(basename $1) ]; then
      run ln -s $1
    elif [ ! -e $1 ]; then
      print_and_log "Tried to make a symlink to $1, but it doesn't exist"
      remove_pid_and_exit_in_error
    fi
  fi
}

### download_uri_target_to_dir
## Returns the local, downloaded file with absolute path.
##
## $1 :: the URI, can be file:///tmp/file, http://server/file or
##      https://file. If $1 is a local file reference, it's used as it
##      is.
## $2 :: the target dir
## $3 :: the target filename. If left empty, the bassename of $1 is used
function download_uri_target_to_dir() {
  local uri=$1
  local target_dir=$2
  local target_file=$3
  make_dir $target_dir

  if [[ $uri == "http://"* || $uri == "https://"* ]]; then

    if [ -z $target_file ] ; then
      target_file=$(basename $uri)
    fi

    log "Downloading" $uri "to" $target_dir "..."
    run cd $target_dir
    run wget \
      $wget_opts \
      $wget_auth \
      --server-response \
      --output-document "$target_file" \
      $uri
  elif [[ $uri == "s3://"* ]]; then

    if [ -z $target_file ] ; then
      target_file=$(basename $uri)
    fi

    log "Downloading" $uri "to" $target_dir "..."
    run cd $target_dir
    run s3cmd get $uri $target_file

  else

    local file=$uri
    if [[ $uri == "file://"* ]] ; then
      # length of file:// is 7
      file=${file:7}
    fi

    if [ -z $target_file ] ; then
      run cp $file $target_dir
    else
      run cp $file $target_dir/$target_file
    fi

  fi
}

### curl_download_uri_target_to_dir
## Returns the local, downloaded file with absolute path.
##
## $1 :: http://server/file or
##       https://file. The $1 should only be a http/https url
## $2 :: the target dir
## $3 :: the target filename. If left empty, the bassename of $1 is used
function curl_download_uri_target_to_dir() {
  local uri=$1
  local target_dir=$2
  local target_file=$3
  make_dir $target_dir

  if [[ $uri == "http://"* || $uri == "https://"* ]]; then

    if [ -z $target_file ] ; then
      target_file=$(basename $uri)
    fi

    log "Downloading" $uri "to" $target_dir "..."
    run cd $target_dir
    run curl \
      --location \
      --output "$target_file" \
      $uri
  fi
}

### verify_that_archive_is_ok
## Will verify that the archive passed to the function is ok. If it's
## not, the function will terminate the calling script, exiting in
## error.
##
## $1 :: the archive to test, supported archives are: .zip, .tar.gz, .tgz
function verify_that_archive_is_ok() {
  if [ -z $1 ]; then
    return
  fi

  if [ ! -e $1 ]; then
    print_and_log "$1 doesn't exist :-("
    remove_pid_and_exit_in_error
  fi

  if [[ $1 == *.zip || $1 == *.jar || $1 == *.ear ]]; then
    unzip -t $1 > /dev/null 2>&1
  elif [[ $1 == *.tar.gz || $1 == *.tgz ]]; then
    tar tzf $1 > /dev/null 2>&1
  fi

  if [ $? -gt 0 ]; then
    print_and_log $1 "is a corrupt archive :-("
    remove_pid_and_exit_in_error
  fi
}

## verifies that the passed file(s) exist and are readable, depends on
## set_archive_files_depending_on_profile
##
## $@ :: a list of files
function verify_that_files_exist_and_are_readable()
{
  debug "Verifying that the file(s) exist(s) and are readable: $@"

  for el in $@; do
    if [[ $el == http* ]]; then
      if [ $(curl -s -I $el | wc -l) -gt 0 ]; then
        continue
      else
        print_and_log "The URI $el doesn't exist, I will exit now."
        remove_pid_and_exit_in_error
      fi
    fi

    if [ ! -e $el ]; then
      print_and_log "The file" $el "doesn't exist. I will exit now."
      remove_pid_and_exit_in_error
    elif [ ! -r $el ]; then
      print_and_log "The file" $el "isn't readable. I will exit now."
      remove_pid_and_exit_in_error
    fi
  done
}

## Verifies that both the file and its parent directory are writeable.
##
## $@ :: the file
function verify_that_directory_and_file_are_writeable() {
  local dir=`dirname $1`
  if [ ! -e $dir ]; then
    print $1: $dir " doesn't exist"
    exit 1
  fi
  if [ ! -w $dir ]; then
    print $1: $dir " isn't writable for user $USER"
    exit 1
  fi

  if [ -e $1 ]; then
    if [ ! -w $1 ]; then
      print $1 "exists, "
      print "but isn't write-able for user $USER"
      exit 1
    fi
  fi
}

### get_file_age_in_seconds
## Returns the number of seconds since the file was changed.
##
## $1 :: the file
function get_file_age_in_seconds() {
  if [ ! $1 ]; then
    return
  elif [ ! -e $1 ]; then
    return
  fi

  local changed=$(stat -c %Y "$1")
  local now=$(date +%s)

  echo $(( now - changed ))
}

### verify_writable_dir_list
## Verifies that the passed list of directories exist and are
## writeable by $USER. If not, the program will exit.
##
## $@ :: a list of directories
function verify_writable_dir_list() {
  for dir in "$@"; do
    if [ ! -w $dir ]; then
      print_and_log "The directory $dir must exist and be writable by" \
        "by $USER for $(basename $0) to work"
      remove_pid_and_exit_in_error
    fi
  done
}

### verify_readable_dir_list
## Verifies that the passed list of directories exist and are
## readable by $USER. If not, the program will exit.
##
## $@ :: a list of directories
function verify_readable_dir_list() {
  for dir in "$@"; do
    if [ ! -r $dir ]; then
      print_and_log "The directory $dir must exist and be readable by" \
        "by $USER for $(basename $0) to work"
      remove_pid_and_exit_in_error
    fi
  done
}
