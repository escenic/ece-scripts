
function list_versions() {
  if [ -z "$type_pid" ]; then
    print "$instance instance of $type on $HOSTNAME is NOT running"
    exit 1
  fi
  
  set_type_port
  
  local version_manager=browser/Global/neo/io/managers/VersionManager
  local url=$(get_escenic_admin_url)/$version_manager
  
  print "Installed on the ${instance} instance running on port ${port}:"
  wget --timeout 30 $wget_opts $wget_appserver_auth -O - $url  2>/dev/null | \
    sed '1,/String Value/d' | sed '/<HR>/,$d' | \
    tr -d '\n' | \
    sed 's/Name\=io/Name\=content-engine/g' | \
    sed 's/Name\=//g' | \
    sed 's/;[^]]* Version=\([^];]*\)[^]]*/ \1/g' | \
    sed 's/\[//g' | \
    sed 's/\]//g' | \
    awk -F',' '{for (i = 1; i <= NF; i++) print "   * " $i;}' | \
    sed 's/\*\ \ \ /\*/g' | \
    sort

    # The last sed is a hack since that for some reason, cannot get
    # sub(/^[ \t]+/, "") to work inside the loop for $i, it seems
    # to always operate on the incoming line.
}
