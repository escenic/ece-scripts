#!/bin/bash

# Emacs: -*- mode: sh; sh-shell: bash; -*-

function _apply_conf_defaults() {
  _apply_conf_config_file=
  _apply_conf_engine_url=http://localhost:8080
  _apply_conf_dry_run=false
  _apply_conf_force=false
  _apply_conf_password="admin"
  _apply_conf_verbosity=1
  _apply_conf_exit_on_error=true
  _apply_conf_engine_up=false
}


function _apply_conf_usage() {
  cat <<EOF
$(basename "$0") apply-conf: Upload shared resources and create
publications in Content Store.

This command takes an .ini file describing an organization, and:

* Creates organizational units
* Creates publication types
* Creates tag structures
* Uploads shared resources
* Uploads publication resources
* Creates publications

This process takes a pristine Content Store and makes it ready for
normal use.  It can also be used to refresh the configuration, by
updating the shared and publication resources.

Usage:

  $(basename "$0") apply-conf <options>

Options:
  -c, --config <file name>: The name of the .ini file which describes
    the organization, relative to PWD or the root of the file
    specified by '--file'.

  --engine <engine URL>: The base URL of Content Engine.
    'escenic-admin' is expected to be available.  Defaults to
    "$_apply_conf_engine_url".

  --password <password>: The password to assign to all created
    publications.  The default is "$_apply_conf_password".

  --fail: Quit with an error as soon as any resource is unable to be
    uploaded (the default)

  --no-fail: Continue uploading resources even though some fail.

  --force: If some resources already exist, the process is aborted, so
    as to not taint an already initialized system.  Use with care,
    since this unceremoniously overwrites any resources that might
    have been there from before, possibly resulting in a system that
    does not match the desired configuration.

  -n, --dry-run: Don't actually do anything, just print out what it
    would have done, indicating if the process would or would not
    require a --force to complete.

  -v, --verbose: Log more information to stderr.

  -q, --quiet: Don't log anything


Configuration
-------------

A configuration file is an .ini file with the following sections:

* "[shared]" lists shared resources, with the following optional keys:
  "publication-types", "workflows", "story-elements",
  "storyline-templates", "containers", "search-filters" and
  "source-monitors".  Each key can list one or more files (comma
  separated, wildcards allowed).

* "[OU name=Name of OU]" specifies an OU, with the optional key
  "description".

* "[tag uri=tag:uri.of.tag,1234]" specifies a tag structure, with the
  keys "name" (mandatory), "description" and "tags" (both optional),
  the latter of which can specify the name of a file containing tags
  to import.

* "[publication name=name-of-publication]" specifies a single
  publication, with the following keys: "OU", "type" that list the
  name of the OU and the name of the type of publication,
  respectively, "content-type", "content", "layout", "layout-group",
  which provide one or more files to upload as publication resources.

Lines starting with ; or # are treated as comments.


Example .ini file
-----------------

    [shared]
    publication-types = publication-types/*.xml

    [OU name=Corporate]
    description = The corporation

    [publication name=intranet]
    ; Files are loaded in alphabetical order
    content-type = publication/content-type-*.xml
    layout = publication/layout.xml
    layout-group = publication/layout-group-*.xml


EOF
  remove_pid_and_exit_in_error
}

function _apply_conf_debug() {
  if [ $_apply_conf_verbosity -ge 2 ] ; then
    echo >&2 "$@"
  fi
  log "$@"
}

function _apply_conf_debug_debug() {
  if [ $_apply_conf_verbosity -ge 3 ] ; then
    echo >&2 "$@"
    log "$@"
  fi
}


function _apply_conf_parse_opts() {
  if [ $# -eq 0 ]; then
    _apply_conf_usage;
    exit 1;
  fi

  local shortopts="c:qnv";
  local longopts="config:,dry-run,engine:,fail,force,no-fail,password:,quiet,verbose";

  local TEMP
  TEMP=$(getopt -o $shortopts -l $longopts -n "$0" -- "$@") || exit $?

  # Note the quotes around `$TEMP': they are essential!
  eval set -- "$TEMP"

  while true ; do
    case "$1" in
      -c|--config) _apply_conf_config_file="$2" ; shift 2 ;;
      --engine) _apply_conf_engine_url="$2" ; shift 2 ;;
      --force) _apply_conf_force=true; shift 1 ;;
      --fail) _apply_conf_exit_on_error=true; shift 1 ;;
      --no-fail) _apply_conf_exit_on_error=false; shift 1 ;;
      --password) _apply_conf_password=$1; shift 2 ;;
      -n|--dry-run) _apply_conf_dry_run=true; shift 1 ;;
      -v|--verbose) _apply_conf_verbosity=$((_apply_conf_verbosity + 1)) ; shift 1 ;;
      -q|--quiet) _apply_conf_verbosity=0 ; shift 1 ;;
      --) shift ; break ;;
      *) echo "Unhandled option $1!" ; exit 1 ;;
    esac
  done
  if [ $# -gt 0 ]; then
    print_and_log "Unknown option: $@"
    remove_pid_and_exit_in_error
  fi
}

function _apply_conf_sanity_check() {
  if [ -z "$_apply_conf_config_file" ] ; then
    print_and_log "No config file specified."
    remove_pid_and_exit_in_error
  fi
  if [ -z "$_apply_conf_engine_url" ] ; then
    print_and_log "No engine URL specified."
    remove_pid_and_exit_in_error
  fi
  if grep -E -q '^[[:space:]]*\[.*"' "$_apply_conf_config_file" ; then
    print_and_log "$_apply_conf_config_file cannot have .ini sections with quotes in them"
    remove_pid_and_exit_in_error
  fi
  # Remove traisling slash from engine URL (leaving "http://engine:8080")
  _apply_conf_engine_url=${_apply_conf_engine_url%/}
}


function _apply_conf_check_dependency() {
  assert_commands_available xmlstarlet curl
}


# Upload a file $1 to location $2 using mime type $3
function _apply_conf_put() {
  local file=$1
  local location=$2
  local mimetype=$3
  local url=${_apply_conf_engine_url}/escenic-admin/${location}
  local reason="missing"
  # check if it exists already
  if _apply_conf_url_exists "${url}" ; then
    if _apply_conf_url_equal "${url}" "$file" ; then
      _apply_conf_debug_debug "${url} doesn't differ from ${file}. Not uploading."
      return 0
    elif $_apply_conf_force ; then
      reason="modified, forced overwrite"
      _apply_conf_debug "Forced overwriting $url."
    else
      if "$_apply_conf_dry_run" ; then
        print_and_log "Dry run: Not overwriting updated '$url'.  Use --force to overwrite."
      else
        _apply_conf_debug "Not overwriting $url.  Use --force to overwrite."
      fi
      return 0
    fi
  fi

  if "$_apply_conf_dry_run" ; then
    print_and_log "Dry run: Uploading '$file' to '$location' ($reason)."
  else
    _apply_conf_debug_debug "Uploading '$file' to '$location' ($reason)."
    curl -X PUT --silent --fail --show-error "${url}" --data-binary "@$file"
  fi
}


function _apply_conf_splice_content() {
  local first_file=$1
  local file=
  xmlstarlet tr <(
    cat <<'EOF'
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:output indent="yes" method="xml"/>

  <!-- identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- In the root element, append all extra files -->
  <xsl:template match="/*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
EOF
    for file in "${@:2}" ; do
      cat <<EOF
      <xsl:for-each select="document('${file}')/*/*">
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:for-each>
EOF
    done
    cat <<EOF
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
EOF
  ) "${first_file}"
}


# $1 file to upload
function _apply_conf_upload_workflow() {
  local file=$1
  _apply_conf_debug "Found workflow $file."
  local name
  name=$(xmlstarlet sel -N sc="http://www.w3.org/2005/07/scxml" -t -m /sc:scxml -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a workflow definition."
  _apply_conf_put "$file" "shared-resources/escenic/workflow/content/$name" application/scxml+xml
}

: <<EOF
<publication-type xmlns="http://xmlns.escenic.com/2019/publication-type"
                  xmlns:ui="http://xmlns.escenic.com/2008/interface-hints"
                  name="facebook">
EOF
function _apply_conf_upload_publication_type() {
  local file=$1
  _apply_conf_debug "Found publication type $file."
  local name
  name=$(xmlstarlet sel -N p="http://xmlns.escenic.com/2019/publication-type" -t -m /p:publication-type -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a publication type definition."
  _apply_conf_put "$file" "shared-resources/escenic/publication-type/$name" application/xml
}

: <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<story-element-type xmlns="http://xmlns.escenic.com/2008/content-type"
  xmlns:ui="http://xmlns.escenic.com/2008/interface-hints" name="interview">
  <ui:label>Interview</ui:label>
  <elements>
EOF
function _apply_conf_upload_story_element_type() {
  local file=$1
  _apply_conf_debug "Found story element $file."
  local name
  name=$(xmlstarlet sel -N ct="http://xmlns.escenic.com/2008/content-type" -t -m /ct:story-element-type -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a story element type definition."
  _apply_conf_put "$file" "shared-resources/escenic/story-element-type/$name" application/xml
}

: <<EOF
<?xml version="1.0"?>
<storyline-template xmlns="http://xmlns.escenic.com/2008/content-type"
          xmlns:ui="http://xmlns.escenic.com/2008/interface-hints"
          name="default">
  <ui:label>Default</ui:label>
  <ui:description>The default template with a required headline</ui:description>
EOF
function _apply_conf_upload_storyline_template() {
  local file=$1
  _apply_conf_debug "Found storyline template $file."
  local name
  name=$(xmlstarlet sel -N ct="http://xmlns.escenic.com/2008/content-type" -t -m /ct:storyline-template -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a storyline template definition."
  _apply_conf_put "$file" "shared-resources/escenic/storyline-template/$name" application/xml
}

: <<EOF
<container-type
  xmlns="http://xmlns.escenic.com/2019/container-type"
  xmlns:ct="http://xmlns.escenic.com/2008/content-type"
  xmlns:ui="http://xmlns.escenic.com/2008/interface-hints"
  xmlns:doc="http://xmlns.vizrt.com/2010/documentation"
  version="4"
  name="breaking">
EOF
function _apply_conf_upload_container_type() {
  local file=$1
  _apply_conf_debug "Found container type $file."
  local name=
  name=$(xmlstarlet sel -N ct="http://xmlns.escenic.com/2019/container-type" -t -m /ct:container-type -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a container type definition."
  _apply_conf_put "$file" "shared-resources/escenic/container-type/$name" application/xml
}

: <<EOF
<search-filter xmlns="http://xmlns.escenic.com/2018/search-filter"
  xmlns:ui="http://xmlns.escenic.com/2008/interface-hints" name="main">

EOF
function _apply_conf_upload_search_filter() {
  local file=$1
  _apply_conf_debug "Found search filters $file."
  local name=
  name=$(xmlstarlet sel -N sf="http://xmlns.escenic.com/2018/search-filter" -t -m /sf:search-filter -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a search filter definition."
  _apply_conf_put "$file" "shared-resources/escenic/search-filter/$name" application/xml
}

: <<EOF
<source-monitor xmlns="http://xmlns.escenic.com/2018/source-monitor"
               xmlns:ui="http://xmlns.escenic.com/2008/interface-hints"
               name="some-editors_workspace" search-filter="some-editors-workspace">
  <ui:label>SoMe Editors Workspace</ui:label>

EOF
function _apply_conf_upload_source_monitor() {
  local file=$1
  _apply_conf_debug "Found source monitor $file."
  local name=
  name=$(xmlstarlet sel -N sm="http://xmlns.escenic.com/2018/source-monitor" -t -m /sm:source-monitor -v @name "$file")
  [ -n "$name" ] || handle_error "The file '$file' does not seem to be a source monitor definition."
  _apply_conf_put "$file" "shared-resources/escenic/source-monitor/$name" application/xml
}


function _apply_conf_uncomma() {
  echo "${@//,/ }"
}

# relativize the arguments to the config file location
# $1 .. $n arguments, possibly containing wildcards, of relative paths
# returns the same arguments, but including the dirname of the config file
function _apply_conf_relativize () {
  local a=
  for a in "${@}" ; do
    if [ "${a:0:1}" == "/" ] ; then
      echo "$a"
    else
      echo "$(dirname "$_apply_conf_config_file")/$a"
    fi
  done
}

function handle_error() {
  local rc=$?
  print_and_log "$@"
  if $_apply_conf_exit_on_error ; then
    print_and_log "Use --no-fail to ignore these errors."
    remove_pid_and_exit_in_error
    exit $rc
  fi
}


# TODO: upload shared resources that live inside [publication] sections too!
function _apply_conf_upload_shared_resources() {
  local _apply_conf_config_shared_workflows=
  local _apply_conf_config_shared_publication_types=
  local _apply_conf_config_shared_story_elements=
  local _apply_conf_config_shared_storyline_templates=
  local _apply_conf_config_shared_search_filters=
  local _apply_conf_config_shared_source_monitors=
  local a=
  _apply_conf_parse_ini_file "$_apply_conf_config_file" _apply_conf_config shared || exit $?
  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_workflows")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_workflow "$a" || handle_error "An error occurred while processing workflow $a"
    fi
  done

  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_publication_types")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_publication_type "$a" || handle_error "An error occurred while processing publication type $a"
    else
      false || handle_error "The publication type '$a' could not be found."
    fi
  done

  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_story_elements")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_story_element_type "$a" || handle_error "An error occurred while processing story element type $a"
    else
      false || handle_error "The story element type '$a' could not be found."
    fi
  done

  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_storyline_templates")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_storyline_template "$a" || handle_error "An error occurred while processing storyline template $a"
    else
      false || handle_error "The storyline template '$a' could not be found."
    fi
  done

  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_search_filters")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_search_filter "$a" || handle_error "An error occurred while processing search filter $a"
    else
      false || handle_error "The search filter '$a' could not be found."
    fi
  done

  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_source_monitors")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_source_monitor "$a" || handle_error "An error occurred while processing source monitor $a"
    else
      false || handle_error "The source monitor '$a' could not be found."
    fi
  done
}

function _apply_conf_upload_shared_resources_after_creating_publications() {
  local _apply_conf_config_shared_containers=
  local a=
  _apply_conf_parse_ini_file "$_apply_conf_config_file" _apply_conf_config shared || exit $?
  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$_apply_conf_config_shared_containers")) ; do
    if [ -f "$a" ] ; then
      _apply_conf_upload_container_type "$a" || handle_error "An error occurred while processing container type $a"
    else
      false || handle_error "The container type '$a' could not be found."
    fi
  done
}


function _apply_conf_create_tag_structure() {
  local identifier=$1

  local create_tag_structure_url=${_apply_conf_engine_url}/escenic-admin/do/classification/tag-structure/new

  # scope these variables :)
  local tag_tag_tags=
  local tag_tag_name=
  local tag_tag_description=
  _apply_conf_parse_ini_file "$_apply_conf_config_file" tag tag "uri=$identifier"  || exit $?

  [ -n "$tag_tag_name" ] || {
    handle_error "Please include a name= in the [tag uri=$identifier]."
    return;
  }

  if "$_apply_conf_dry_run" ; then
    print_and_log "Dry run: Creating the tag structure '$identifier'."
  else
    _apply_conf_debug "Creating the tag structure '$identifier'."
    local html=
    if ! html=$(curl --silent --fail --show-error "$create_tag_structure_url" --data-urlencode "identifier=${identifier#tag:}" --data-urlencode "name=$tag_tag_name" --data-urlencode "description=$tag_tag_description") ; then
      handle_error "An error occurred while creating the tag structure '$identifier'."
    fi
    local updated_tags=$(_apply_conf_list_tag_structures)
    if [[ " $updated_tags " != *" $identifier "* ]] ; then
      _apply_conf_debug "$html"
      handle_error "An error occurred while creating the tag structure '$identifier'."
    fi

  fi

  # If there's a file with some tags in it,
  local file=
  for file in $(_apply_conf_relativize $(_apply_conf_uncomma "$tag_tag_tags")) ; do
    if "$_apply_conf_dry_run" ; then
      print_and_log "Dry run: Importing tags in '${file}' to tag structure '$identifier'."
    else
      _apply_conf_debug "Importing tags in '${file}' to tag structure '$identifier'."
      local importURL=${_apply_conf_engine_url}/escenic-admin/do/classification/import
      curl --silent --fail --show-error -F "import=true" -F "identifier=$identifier" -F "file=@${file}" "${importURL}" > /dev/null ||
        handle_error "An error occurred while importing the tags $file to the tag structure $identifier."
    fi
  done
}

function _apply_conf_create_organizational_unit() {
  local name=$1

  local create_ou_url=${_apply_conf_engine_url}/escenic-admin/do/ou/store

  # scope these variables :)
  local ou_ou_description=
  _apply_conf_parse_ini_file "$_apply_conf_config_file" ou ou "name=$name"  || exit $?

  if ${_apply_conf_dry_run} ; then
    print_and_log "Dry run: Creating the organizational unit '${name}'."
  else
    _apply_conf_debug "Creating the organizational unit '${name}'."
    curl --silent --fail --show-error "$create_ou_url" --data-urlencode "name=$name" --data-urlencode "information=$ou_ou_description" > /dev/null
  fi
}

# grab all OUs in the form "id:uuid:name"
# 1:abc-123-uuid-1:foo
# 2:abc-123-uuid-2:bar
function _apply_conf_get_existing_organizational_units() {
  local url=${_apply_conf_engine_url}/escenic-admin/pages/ou/list.jsp
  curl --silent --fail --show-error "$url" | sed -n /'data-ou='/s,".*data-ou=[\"']\\([^\"']*\\)[\"'].*",'\1',p
}

function _apply_conf_create_organizational_units() {
  local existing_ous=
  existing_ous=$(_apply_conf_get_existing_organizational_units)
  local existing_ou_names=
  # One OU on each line
  # foo
  # bar
  existing_ou_names="$(cut -f 3- -d : <<< "$existing_ous")"
  if [ -z "$existing_ou_names" ] && ! $_apply_conf_force ; then
    print_and_log "There are no OUs defined, not even the built-in Escenic OU.  This is probably because I require Content Engine 7.4.0 or newer in order to function.  If you believe this is an error, you can specify the --force option."
    exit 123
  fi
  _apply_conf_debug "Found the following OUs to exist:" ${existing_ou_names}

  # one OU on each line.
  local ous_to_create=
  ous_to_create=$(_apply_conf_get_sections_from_ini_file "$_apply_conf_config_file" OU | sed -n /^name=/s/name=//p)

  _apply_conf_debug "Found the following OUs in the configuration:" ${ous_to_create}

  local ou=
  while read -r ou; do
    # TODO match full string
    if grep -q -F "$ou" <<< "$existing_ou_names" ; then
      _apply_conf_debug "Organizational unit $ou already exists.  Skipping."
      continue
    fi
    _apply_conf_debug "Creating organizational unit $ou."

    _apply_conf_create_organizational_unit "$ou"
  done <<< "$ous_to_create"
}

function _apply_conf_get_session_cookie_from_url() {
  local url=$1
  curl \
    --silent \
    --fail \
    --show-error \
    --head "${url}" |
    grep -i "^Set-Cookie:" |
    sed s/'.*JSESSIONID=\([^;]*\).*'/'\1'/
}



# Upload one resource file
## $1 - a session cookie
## $2 - the name of the resource
## $3 - the file to upload
function _apply_conf_upload_resource_file() {
  local cookie=$1
  local name=$2
  local file=$3
  if [ ! -f "$file" ] ; then
    false || handle_error "The resource $name ($file) was not available."
  fi
  log "Uploading $file to $name using session $cookie."
  if ${_apply_conf_dry_run} ; then
    print_and_log "Dry run: Uploading resource '$file' to '$name'."
  else
    _apply_conf_debug "Uploading resource '$file' to '$name'."
    curl --silent --fail --show-error \
         -F "type=${name}" \
         -F "resourceFile=@${file}" \
         --cookie JSESSIONID="${cookie}" \
         "${_apply_conf_engine_url}/escenic-admin/do/publication/resource" > /dev/null ||
      handle_error "Return code $? while uploading $file to $name"
  fi
}


function _apply_conf_read_publication_config() {
  name=$1
  _apply_conf_parse_ini_file "$_apply_conf_config_file" publication publication "name=$name"  || exit $?

  [ -n "$publication_publication_type" ] || {
    handle_error "Please include a type= in the [publication name=$name]."
    return 1;
  }

  [ -n "$publication_publication_ou" ] || {
    handle_error "Please include a OU= in the [publication name=$name]."
    return 1;
  }

  [ -n "$publication_publication_content_type" ] || {
    handle_error "Please include a content-type= in the [publication name=$name]."
    return 1;
  }

  [ -n "$publication_publication_layout" ] || {
    handle_error "Please include a layout= in the [publication name=$name]."
    return 1;
  }
}


# Publication does not exist.  Create it, or (with dry run) show what it would do.
function _apply_conf_update_publication_resources() {
  local name=$1
  local admin_url=${_apply_conf_engine_url}/escenic-admin
  local publication_publication_type=
  local publication_publication_ou=
  local publication_publication_content=
  local publication_publication_content_type=
  local publication_publication_layout=
  local publication_publication_layout_group=

  if ! _apply_conf_read_publication_config "$name" ; then
    return
  fi

  local index=0
  for resource in $(_apply_conf_relativize $(_apply_conf_uncomma "$publication_publication_content_type")) ; do
    if [ $index -eq 0 ] ; then
      resourceName=/escenic/content-type
    else
      resourceName=/escenic/content-type/$(basename "$resource" .xml)
    fi
    _apply_conf_put "${resource}" "publication-resources/${name}${resourceName}"
    index=$(( index + 1 ))
  done

  resource=$(_apply_conf_relativize "$publication_publication_layout_group")
  if [ -f "$resource" ] ; then
    _apply_conf_put  "${resource}" "publication-resources/${name}/escenic/layout-group"
  fi

  resource=$(_apply_conf_relativize $(_apply_conf_uncomma "$publication_publication_layout"))
  if [ -f "$resource" ] ; then
    _apply_conf_put "${resource}" "publication-resources/${name}/escenic/layout"
  fi
}

# Publication does not exist.  Create it, or (with dry run) show what it would do.
function _apply_conf_create_publication() {
  local name=$1
  local admin_url=${_apply_conf_engine_url}/escenic-admin
  local create_publication_url=${admin_url}/do/publication/insert


  : <<EOF
type = twitter
OU = My OU
search-filters = tomorrow-facebook/common/some-editors-workspace.xml
source-monitors = tomorrow-facebook/common/some-editors-workspace.xml
content-type = tomorrow-facebook/publication/content-types/facebook_post.xml
content = some.xml
layout-group = some.xml
EOF

  # type
  local publication_publication_type=
  local publication_publication_ou=
  local publication_publication_content=
  local publication_publication_content_type=
  local publication_publication_layout=
  local publication_publication_layout_group=

  # Discovered UUID based on name
  local ou_uuid=

  # Skip ou_uuid check if dry-run
  if "$_apply_conf_dry_run" ; then
    ou_uuid=DRY_RUN
  fi

  if ! _apply_conf_read_publication_config "$name" ; then
    return
  fi

  local existing_ous=
  existing_ous=$(_apply_conf_get_existing_organizational_units)
  while read -r ou ; do
    local ou_name=$(cut -d : -f 3- <<< "$ou")
    if [ "$ou_name" == "$publication_publication_ou" ] ; then
      ou_uuid=$(cut -d : -f 2 <<< "$ou")
    fi
  done <<< "$existing_ous"

  if [ -z "$ou_uuid" ] ; then
    false || handle_error "Unable to find OU with name '$publication_publication_ou'."
  fi

  if ! "$_apply_conf_dry_run" ; then
    local cookie=
    cookie=$(_apply_conf_get_session_cookie_from_url "$admin_url"/)
  else
    cookie=DRY_RUN
  fi

  if [ -z "$cookie" ] ; then
    print_and_log "Unable to get a session cookie."
    remove_pid_and_exit_in_error
    exit 123
  fi

  local resource=
  local resource_data=
  local index=0
  local resourceName=
  for resource in $(_apply_conf_relativize $(_apply_conf_uncomma "$publication_publication_content_type")) ; do
    if [ $index -eq 0 ] ; then
      resourceName=/escenic/content-type
    else
      resourceName=/escenic/content-type/$(basename "$resource" .xml)
    fi
    _apply_conf_upload_resource_file $cookie $resourceName "${resource}"
    index=$(( index + 1 ))
  done

  resource=$(_apply_conf_relativize "$publication_publication_layout_group")
  if [ -f "$resource" ] ; then
    _apply_conf_upload_resource_file $cookie /escenic/layout-group "${resource}"
  fi

  resource=$(_apply_conf_relativize $(_apply_conf_uncomma "$publication_publication_layout"))
  # throw an error if more than one layout file is specified?!
  _apply_conf_upload_resource_file $cookie /escenic/layout "${resource}"

  resource=()
  for a in $(_apply_conf_relativize $(_apply_conf_uncomma "$publication_publication_content")) ; do
    xmlstarlet val -q "${a}" || {
      handle_error "The content file '${a}' is not well formed XML."
      # ignore file if --no-error
      continue
    }
    resource=( "${resource[@]}" "$a" )
  done
  if [ "${#resource[@]}" -eq 1 ] ; then
    resource="${resource[0]}"
  elif [ "${#resource[@]}" -gt 1 ] ; then
    # More than one content files.  Splice them, and store the result in a temp-file.
    local resource_data
    resource_data=$(_apply_conf_splice_content "${resource[@]}") || handle_error "Unable to splice content files ${resource[*]}."
    resource=
  else
    resource=
  fi

  if [ -n "$resource" ] ; then
    _apply_conf_upload_resource_file $cookie /escenic/content "${resource}"
  elif [ -n "$resource_data" ] ; then
    _apply_conf_upload_resource_file $cookie /escenic/content <(echo "${resource_data}")
  fi


  if "$_apply_conf_dry_run" ; then
    print_and_log "Dry run: Creating publication $name in OU $publication_publication_ou ($ou_uuid)"
  else
    _apply_conf_debug "Creating publication $name in OU $publication_publication_ou ($ou_uuid)."
    local html=
    html=$(
      curl --silent --fail --show-error "${create_publication_url}" \
           --data-urlencode "name=${name}" \
           --data-urlencode "publisherUUID=${ou_uuid}" \
           --data-urlencode "publicationType=${publication_publication_type}" \
           --data-urlencode "adminPassword=${_apply_conf_password}" \
           --data-urlencode "adminPasswordConfirm=${_apply_conf_password}" \
           --cookie JSESSIONID="${cookie}"
        )
    if ! _apply_conf_get_publications | grep -q ":${name}" ; then
      _apply_conf_debug "$html"
      handle_error "Unable to create publication $name."
    fi
  fi
}



# Print a list of publications
# 1:foo
# 2:bar
function _apply_conf_get_publications() {
  local url=${_apply_conf_engine_url}/escenic-admin/pages/publication/list.jsp
  curl --silent --fail --show-error "$url" | sed -n /'data-publication='/s,".*data-publication=[\"']\\([^\"']*\\)[\"'].*",'\1',p
}

function _apply_conf_create_publications() {
  local existing_publications=
  existing_publications=$(_apply_conf_get_publications)

  local existing_publication_names=
  existing_publication_names="$(cut -f 2- -d : <<< "$existing_publications" | xargs)"
  _apply_conf_debug "Found the following publications to exist: ${existing_publication_names// /, }."

  local publications_to_create=
  publications_to_create=$(_apply_conf_get_sections_from_ini_file "$_apply_conf_config_file" publication | sed -n /^name=/s/name=//p)

  local publication=
  for publication in $publications_to_create ; do
    if [[ " $existing_publication_names " == *" $publication "* ]] ; then
      _apply_conf_debug "Publication $publication already exists.  Updating publication resources."
      _apply_conf_update_publication_resources "$publication"
      continue
    fi
    _apply_conf_debug "Setting up publication $publication."

    _apply_conf_create_publication "$publication"
  done
}

function _apply_conf_list_tag_structures() {
  local url=${_apply_conf_engine_url}/escenic-admin/do/classification/display
  curl --silent --fail "$url" | sed -n /'data-structure='/s,".*data-structure=[\"']\\([^\"']*\\)[\"'].*",'\1',p | xargs
}

function _apply_conf_create_tag_structures() {
  local existing_tags=
  existing_tags=$(_apply_conf_list_tag_structures)
  _apply_conf_debug "Found the following tag structures to exist: ${existing_tags// /, }."

  local tags_to_create=
  tags_to_create=$(_apply_conf_get_sections_from_ini_file "$_apply_conf_config_file" tag | sed -n /^uri=/s/uri=//p)

  local tag=
  for tag in $tags_to_create ; do
    if [[ " $existing_tags " == *" $tag "* ]] ; then
      if $_apply_conf_force ; then
        _apply_conf_debug "Forcing re-creation of tag structure $tag."
      else
        _apply_conf_debug "Tag structure $tag already exists.  Use --force to reimport tags."
        continue
      fi
    fi
    _apply_conf_debug "Creating tag structure $tag."

    _apply_conf_create_tag_structure "$tag"
  done
}


function _apply_conf_perform_work() {
  # Check if Engine is running first
  if _apply_conf_url_exists "${_apply_conf_engine_url}/escenic-admin/"; then
    _apply_config_engine_up=true
  else
    if ! ${_apply_conf_dry_run}; then
      print_and_log "Engine (${_apply_conf_engine_url}/escenic-admin/) is not running."
      remove_pid_and_exit_in_error
      exit 2
    fi
  fi

  _apply_conf_create_tag_structures
  _apply_conf_upload_shared_resources
  
  _apply_conf_create_organizational_units
  _apply_conf_create_publications

  _apply_conf_upload_shared_resources_after_creating_publications
}


function _apply_conf_main() {
  _apply_conf_check_dependency
  _apply_conf_defaults
  _apply_conf_parse_opts "${@:2}"  # apply-conf' is $1, remove it before processing.
  _apply_conf_sanity_check
  if [ $_apply_conf_verbosity -gt 3 ] ; then
    set -x;
  fi
  _apply_conf_perform_work
}


function cmd_apply_conf() {
  _apply_conf_main "${@}"
}



### Utility functions



function _apply_conf_url_exists() {
  local url=$1
  curl > /dev/null --silent --fail "$url"
}

function _apply_conf_url_equal() {
  local url=$1
  local file=$2
  diff &> /dev/null -q <(curl --silent --fail "$url") "$file"
}


# Given the .ini file
#
#   [AAA]
#   B=C
#   [ZZZ key=value]
#   D-E-F=D E F
#   D-E-F=FOO
#
# then `parse_ini_file foo.ini CONFIG AAA` will set the following
# variables:
#
#   CONFIG_AAA_B=C
#
# `parse_ini_file foo.ini CONFIG ZZZ key=value` will set the following
# variable, note how the result contains a newline because there are two values.
#
#   CONFIG_ZZZ_D_E_F=$'D E F\nFOO'
#
function _apply_conf_parse_ini_file() {
  local file=$1
  local prefix=$2
  local section=$3
  local specifier=$4
  local keys=
  local key=
  [ -z "$file" ] && {
    echo >&2 "No configuration file name specified"
    return 23
  }
  [ ! -e "$file" ] && {
    echo >&2 ".ini file '$file' does not exist"
    return 23
  }
  keys=$(_apply_conf_get_keys_from_ini_file "$file" "$section" "$specifier") || return 74
  for key in $keys ; do
    IFS=$'\n' read -rd '' "${prefix}_${section}_${key//-/_}" <<< "$(_apply_conf_get_from_ini_file "$file" "$section" "$key" "" "$specifier")" || :
  done
  return 0 # Explicitly return 0 because the read call above returns 1...
}


## List the keys of the section $2 (with optional specifier $3) from an ini-file config file $1,
function _apply_conf_get_keys_from_ini_file
{
  # first look for any section of the file between a [$2] and a [
  # If you find it, remove everything after the first "="
  # "I" is for case insensitive.
  local result=
  if [ "$3" == "" ] ; then
    result=$(sed -n "/^[[:space:]]*\\[$2\\]/I,/^\\[/ {
              /^[[:space:]]*[-a-z0-9/@:\\.]*[[:space:]]*=[[:space:]]*/Is/[[:space:]]*=.*//p
            }" "$1" | sort | uniq)
  else
    result=$(sed -n "/^[[:space:]]*\\[$2 [[:space:]]*$3[[:space:]]*\\]/I,/^\\[/ {
              /^[[:space:]]*[-a-z0-9/@:\\.]*[[:space:]]*=[[:space:]]*/Is/[[:space:]]*=.*//p
            }" "$1" | sort | uniq)
  fi
  echo "${result,,}"
}



## List the sections named $2 from an ini-file config file $1,
function _apply_conf_get_sections_from_ini_file
{
  local file=$1
  local name=$2
  sed -n "/^[[:space:]]*\\[[[:space:]]*${name} [[:space:]]*\\(.*\\)[[:space:]]*\\][[:space:]]*$/Is/^[[:space:]]*\\[[[:space:]]*${name}[[:space:]]*\\(.*\\)[[:space:]]*\\][[:space:]]*$/\\1/Ip" "$file"
}



#
## Get the configuration value of a key $3 (with optional specifier $5 from section $2 from a
## ini-file config file $1, printing the default value $4 if it's
## not set.
function _apply_conf_get_from_ini_file() {
  local file=$1
  local section=$2
  local key=$3
  local default=$4
  local specifier=$5
  # first look for any section of the file between a [$2] and a [
  # Within that ({}) look for the "$3 =" with any whitespace interspersed.
  # If you find it, remove everything up to the first "=".
  # "I" is for case insensitive.
  local result=
  if [ -z "$specifier" ] ; then
    result=$(sed -n "/^[[:space:]]*\\[${section}\\]/I,/^\\[/ {
              /^[[:space:]]*${key/\//\/}[[:space:]]*=[[:space:]]*/Is/[^=]*=[[:space:]]*//p
            }" "$file" | sed 's/[[:space:]]*$//' )
  else
    result=$(sed -n "/^[[:space:]]*\\[[[:space:]]*${section} [[:space:]]*${specifier}[[:space:]]*\\]/I,/^\\[/ {
              /^[[:space:]]*${key/\//\/}[[:space:]]*=[[:space:]]*/Is/[^=]*=[[:space:]]*//p
            }" "$file" | sed 's/[[:space:]]*$//' )
  fi
  if [ -z "$result" ] ; then
    echo "$default"
  else
    echo "$result"
  fi
}

