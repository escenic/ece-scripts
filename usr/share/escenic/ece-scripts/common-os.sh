#! /usr/bin/env bash

# Platform/OS specific methods.
#
# by torstein@escenic.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 ||
  source "${BASH_SOURCE[0]%/*}/common-bashing.sh"

## Only used if the Tomcat download mirror couldn't be determined
fallback_tomcat_url="http://apache.uib.no/tomcat/tomcat-7/v7.0.79/bin/apache-tomcat-7.0.79.tar.gz"

# Can be used like this:
# common_io_os_loaded 2>/dev/null || source common-os.sh
function common_os_is_loaded() {
  echo 1
}

### get_user_home_directory
## Method which will try its best to find the home diretory of
## existing users and probable home directories of new users.
##
## - On Darwin/Mac OS X, it will return /Users/<user>
## - On systems using /etc/passwd, it will search there to find the
##   home dir of existing users.
## - For new users, it will check the configuration of adduser (if
##   present).
## - If all of thes above fails, it will return /home/<user>
##
## $1 :: the user name, can either be an existing user or a non-yet
##       created user.
function get_user_home_directory() {
  if [ $(uname -s) = "Darwin" ]; then
    echo /Users/$1
  elif [ $(grep ^$1 /etc/passwd | wc -l) -gt 0 ]; then
    grep ^$1 /etc/passwd | cut -d':' -f6
  elif [ -r /etc/adduser.conf ]; then
    local dir=$(grep DHOME /etc/adduser.conf | grep -v ^# | cut -d'=' -f2)
    echo $dir/$1
  else
    echo "/home/$1"
  fi
}

### has_oracle_java_installed
## Will return 1 if the system has Sun/Oracle Java installed.
function has_oracle_java_installed() {
  local java_bin_list=$(
    find /usr/lib/jvm -maxdepth 3 -name java -type f -executable)

  for java_bin in ${java_bin_list}; do
    local hit=$(${java_bin} -version 2>&1 > /dev/null | grep HotSpot | wc -l)
    if [ ${hit} -gt 0 ]; then
        echo 1
        return
    fi
  done

  # fallback
  if [[ $(java -version 2>&1 > /dev/null | grep HotSpot | wc -l) -gt 0 ]]; then
    echo 1
  else
    echo 0
  fi
}

### create_user_and_group_if_not_present
## $1 :: user name
## $2 :: group name
function create_user_and_group_if_not_present() {
  local user=$1
  local group=$1

  if [ $(grep $user /etc/passwd | wc -l) -lt 1 ]; then
    print_and_log "Creating UNIX user $user ..."

    if [ $on_debian_or_derivative -eq 1 ]; then
      run adduser $user \
        --disabled-password \
        --gecos "Escenic-user,Room,Work,Home,Other"
    fi

    if [ $on_redhat_or_derivative -eq 1 ]; then
      run useradd $user \
        --comment "Escenic-user,Room,Work,Home,Other"
    fi

    add_next_step "I created a new UNIX user called $user"
    add_next_step "and you must set a password using: passwd $user"
  fi

  if [ $(grep $group /etc/group | wc -l) -lt 1 ]; then
    print_and_log "Creating UNIX group $group ..."
    run addgroup $group
  fi
}

### get_ip
## Will return the IP of the host name. If not found, the host name
## passed to the function will be returned.
##
## $1 :: the host name
function get_ip() {
  local ip=$(ping -c 1 $1 2>/dev/null | \
    grep "bytes from" | \
    cut -d'(' -f2 | \
    cut -d ')' -f1)

  if [ -z "$ip" ]; then
    echo $1
  fi

  echo $ip
}

### assert_commands_available
## Asserts that the passed command/program is indeed accessible in the
## current context. If it is not, the program aborts and removes the
## PID.
##
## $@ :: a list of the binary/executable/program
function assert_commands_available() {
  local errors_found=0
  for el in $@; do
    if [ $(which ${el} 2>/dev/null | wc -l) -lt 1 ]; then
      print_and_log "Please install $el and then run $(basename $0) again."
      errors_found=1
    fi
  done

  if [ $errors_found -eq 1 ]; then
    exit 1
  fi
}

function get_tomcat_download_url() {
  local url=
  if [ -n "${tomcat_download}" ]; then
    url=$tomcat_download
  else
    url=$(
        curl -s http://tomcat.apache.org/download-70.cgi | \
            grep tar.gz | \
            head -1 | \
            cut -d'"' -f2
    )
  fi

  if [ -z "${url}" ]; then
    url=$fallback_tomcat_url
    log "Failed to get Tomcat mirror URL, will use fallback URL $url"
  fi

  echo $url
}


### download_tomcat
## Downloads Tomcat from the regional mirror
##
## $1 :: target directory
function download_tomcat() {
  local url=$(get_tomcat_download_url)

  print_and_log "Downloading Tomcat from $url ..."
  download_uri_target_to_dir $url $1
}

### get_free_memory_in_mega_bytes
function get_free_memory_in_mega_bytes() {
  if [ $(uname -s) == "Linux" ]; then
    local free_in_kb=$(
      grep  MemFree /proc/meminfo | \
        cut -d: -f2- | \
        sed 's/^[ ]*//g' | \
        cut -d' ' -f1
    )
    echo $(( $free_in_kb / 1024 ))
  fi
}

### get_total_memory_in_mega_bytes
function get_total_memory_in_mega_bytes() {
  if [ $(uname -s) == "Linux" ]; then
    local total_in_kb=$(
      grep  MemTotal /proc/meminfo | \
        cut -d: -f2- | \
        sed 's/^[ ]*//g' | \
        cut -d' ' -f1
    )
    echo $(( $total_in_kb / 1024 ))
  fi
}

### add_apt_source
##
## $@ :: the apt line to be added if it's not already present.
function add_apt_source() {
  # first, check that the base URL in the sources list returns 200,
  # only allow 20 seconds for this test. If the URL doesn't return
  # 200, the sources list is not added.
  local url=$(echo $@ | cut -d' ' -f2)
  local repo_ok=$(
    curl \
      --silent \
      --head \
      --connect-timeout 20 \
      $url | \
      egrep " 200 OK| 301 Moved Permanently" | \
      wc -l
  )

  if [ $repo_ok -eq 0 ]; then
    print_and_log "$(yellow WARNING)" \
      "The APT repo $url is not OK, not adding it."
    return
  fi

  # Remove HTTP scheme and user/pass when checking if the source
  # already exists.
  local url_fragment=${url##*://}
  url_fragment=${url_fragment##*@}

  if [ "$(grep -r "${url_fragment}" /etc/apt/sources.list* | wc -l)" -lt 1 ]; then
    echo "# added by $(basename $0) @ $(date)" >> $escenic_sources
    echo "$@" >> $escenic_sources
  fi
}

### get_memory_usage_of_pid
## Only works on Linux
function get_memory_usage_of_pid() {
  local file=/proc/$1/status
  if [ ! -e $file ]; then
    # TODO add support for non-Linux systems
    return
  fi

  grep VmSize $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
}

### get_memory_usage_of_pid
## Only works on Linux
function get_memory_summary_of_pid() {
  local file=/proc/$1/status
  if [ ! -e $file ]; then
    # TODO add support for non-Linux systems
    return
  fi

  local size=$(
    grep VmSize $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
  )
  local peak=$(
    grep VmPeak $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
  )

  echo "${size} (peaked at: $peak)"
}

### Returns 0 (ok) if the passed RPM file has been installed on the
### current machine, 1 if not.
##
## $1 :: RPM file reference
function is_rpm_already_installed() {
  local file=$1

  if [ ! -e "${file}" ]; then
    return 1
  fi

  local package_name=
  package_name=$(rpm -qp --queryformat "%{Name}\n" "${file}")
  is_rpm_already_installed_by_name "${package_name}"
}

function is_rpm_already_installed_by_name() {
  local package_name=$1
  rpm -q "${package_name}" &> /dev/null
}
