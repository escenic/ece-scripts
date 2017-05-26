## Module for the 'ece repackage' command.
##
## Repackages an EAR, which  probably will be deployed with 'ece deploy --file <ear>'.
##
## This command replaces the JARs inside the original EAR file with
## the corresponding JARs installed on the systme through APT/RPM.
##
## by torstein@escenic.com

USR_SHARE_DIR=/usr/share/escenic

get_installed_packages_war_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 -name "webapps" -type d | \
    while read -r webapps_dir; do
      find "${webapps_dir}" -name "*.war" -type f
    done
}

get_installed_packages_war_name_list() {
  get_installed_packages_war_list | sed 's#.*[/]##'
}

get_installed_packages_lib_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 -name "lib" -type d | \
    while read -r lib_dir; do
      find "${lib_dir}" -name "*.jar" -type f
    done
}

get_installed_packages_webservice_extensions_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 \
       -name "webservice-extensions" -type d
}

get_installed_packages_webservice_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 \
       -name "webservice" -type d
}

get_installed_packages_studio_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 \
       -name "studio" -type d
}

get_installed_package_webservice_war() {
  find "${USR_SHARE_DIR}/escenic-content-engine-"* -maxdepth 2 \
       -name "webservice.war" -type f
}

get_installed_package_studio_war() {
  find "${USR_SHARE_DIR}/escenic-content-engine-"* -maxdepth 2 \
       -name "studio.war" -type f
}

get_installed_package_webservice_extensions_war() {
  find "${USR_SHARE_DIR}/escenic-content-engine-"* -maxdepth 2 \
       -name "webservice-extensions.war" -type f
}

get_installed_package_content_engine_war_list() {
  find "${USR_SHARE_DIR}/escenic-content-engine-"* -maxdepth 2 \
       -name "*.war" -type f
}

get_installed_package_content_engine_war_name_list() {
  get_installed_package_content_engine_war_list |
    sed 's#.*[/]##'
}

## Normalises the file name so that we can compare two JARs of
## different versions.
##
## $1 :: file name
## $2 :: suffix
get_file_base() {
  local file_name=$1
  local suffix=${2:-}

  file_name=${file_name##*/}

  if [ -n "${suffix}" ]; then
    file_name=${file_name//.${suffix}}
  fi

  # special handling of jar.pack.gz, the gz is removed in the above
  # logic.
  file_name=${file_name//jar.pack}

  printf "%s\n" "${file_name}" |
    sed -r \
        -e 's#-develop-[-\.0-9]+##' \
        -e 's#[-][0-9.-]+##' \
        -e 's#-trunk-SNAPSHOT##' \
        -e 's#-develop-SNAPSHOT##' \
        -e 's#SNAPSHOT##' \
        -e 's#[.]$##' \
        -e 's#(alpha|beta|rc)[.-][0-9]+##'
}

## $1 :: tmp dir with EAR contents
remove_libs_included_in_installed_packages() {
  local tmp_dir=$1

  local package_jar=
  for package_jar in $(get_installed_packages_lib_list); do
    package_jar_base=$(get_file_base "${package_jar}" jar)

    local ear_jar=
    for ear_jar in "${tmp_dir}/lib/"*.jar; do
      ear_jar_base=$(get_file_base "${ear_jar}" jar)
      if [[ "${ear_jar_base}" == "${package_jar_base}" ]]; then
        debug "Removing JAR in EAR, ${ear_jar##*/},
               will be replaced with ${package_jar}"
        run rm "${ear_jar}"
      fi
    done
  done
}

## $1 :: tmp dir with EAR contents
copy_libs_included_in_installed_packages() {
  local tmp_dir=$1
  make_dir "${tmp_dir}/lib"

  local package_jar=
  for package_jar in $(get_installed_packages_lib_list); do
    debug "Including JAR ${package_jar} in EAR ..."
    run cp "${package_jar}" "${tmp_dir}/lib"
  done
}

## $1 :: tmp dir with WAR contents
## $2 :: base name of WAR file
overwrite_webapp_libs_included_in_installed_packages() {
  local tmp_dir=$1
  local war_name=$2

  local is_a_package_war=0
  is_a_package_war=$(
    get_installed_packages_war_name_list |
      grep -c -w "${war_name}" || true)

  local package_dir=
  for package_dir in "${USR_SHARE_DIR}/"*; do
    local template_lib_dir="${package_dir}/template/WEB-INF/lib"
    if [[ ! -d "${template_lib_dir}" ]]; then

      # Only patch the WAR with plugin template libraries if the WAR
      # isn't a plugin webapp (e.g. poll-ws).
      if [ "${is_a_package_war-0}" -eq 0 ]; then
        # ECE and its plugins put their publication specific libraries
        # in different directory structures. This is the location
        # plugins use.
        template_lib_dir="${package_dir}/publication/webapp/WEB-INF/lib"
      fi

      if [ ! -d "${template_lib_dir}" ]; then
        continue
      fi
    fi

    find "${template_lib_dir}" -name "*.jar" -type f | \
      while read -r package_jar; do
        package_jar_base=$(get_file_base "${package_jar}" jar)

        local pub_war_jar=
        for pub_war_jar in "${tmp_dir}/WEB-INF/lib/"*.jar; do
          pub_war_jar_base=$(get_file_base "${pub_war_jar}" jar)
          debug "${FUNCNAME[0]}
                  Checking pub_war_jar=$pub_war_jar
                  pub_war_jar_base=$pub_war_jar_base"

          if [[ "${pub_war_jar_base}" == "${package_jar_base}" ]]; then
            debug " -> Replacing ${pub_war_jar} with ${package_jar}"
            run rm "${pub_war_jar}"
            run cp "${package_jar}" "${pub_war_jar%/*}/."
          else
            debug " -> ${pub_war} doesn't have ${package_jar}, adding it"
            local dir="${pub_war_jar%/*}"
            make_dir "${dir}"
            run cp "${package_jar}" "${dir}/."
          fi
        done
      done
  done
}

## $1 :: the dir where the new EAR will be present
## $2 :: the dir whose contents will form the contents of the new EAR
## $3 :: the old EAR name or HASH
create_new_ear_in_dir() {
  local result_dir=$1
  local dir=$2
  local old_ear=$3

  local new_ear=
  old_ear=${old_ear//-created-on-${HOSTNAME}.zip}

  new_ear="${result_dir}/$(date --iso)-$(date +%s)-repackaged-${old_ear}-created-on-${HOSTNAME}.zip"
  (
    run cd "${dir}"
    run zip --quiet --recurse-paths "${new_ear}" .
  )

  log "The new EAR is ready!: ${new_ear}
       You can deploy it with:
       ece -i ${instance} --file ${new_ear} stop deploy start"

  echo "${new_ear}"
}

## $1 :: war
should_patch_war_with_template_libs() {
  local war=$1
  local war_base=${war##*/}

  local -a should_not_be_patched=(
    $(get_installed_package_content_engine_war_name_list)
  )

  local el=
  for el in "${should_not_be_patched[@]}"; do
    if [[ "${el}" == "${war_base}" ]]; then
      return 1
    fi
  done

  return 0
}

## Overwrite the JAR libraries inside the EAR specific webapps.
##
## $1 :: the dir in which the extracted EAR resides
overwrite_webapp_libs() {
  local dir=$1

  find "${dir}" -name "*.war" | while read -r war; do
    if ! should_patch_war_with_template_libs "${war}"; then
      continue
    fi
    local tmp_dir=
    tmp_dir=$(mktemp -d)

    local start=
    start=$(date +%s)

    run unzip -q "${war}" -d "${tmp_dir}"
    overwrite_webapp_libs_included_in_installed_packages \
      "${tmp_dir}" \
      "${war##*/}"

    # to be sure it's prestine, we delete the old war
    run rm "${war}"
    (
      cd "${tmp_dir}" || exit 1
      run zip --recurse-paths --quiet "${war}" .
    )

    run rm -rf "${tmp_dir}"
    log_profile "Fixing webapp libs for ${war##*/}" "${start}"
  done
}

## In case no local or URI reference to an EAR is passed, the method
## will try to find a sane, local EAR file to use for the repackaging.
##
## The method reads and writes the variables:
##   - file_or_uri and
##   - ear_name_or_hash
##
## $1 :: The file or URI to an EAR, as passed to the 'ece' command
##       with --uri or --file.
ensure_ear_reference_and_lineage_sanity() {
  ## user passed a file or uri, that's easy.
  if [ -n "${file_or_uri}" ]; then
    ear_name_or_hash=${file_or_uri##*/}
    return
  fi

  # this is the fallback ear
  local default_cached_engine_ear=${cache_dir}/engine.ear

  # The deployment log is updated whenever 'ece deploy' is used.
  local deployment_log=
  deployment_log=$(get_deployment_log)

  if [ -r "${deployment_log}" ]; then
    local last_deployed_ear=
    last_deployed_ear=$(awk '{print $7;}' "${deployment_log}" | tail -1)
    last_deployed_hash=$(awk '{print $8;}' "${deployment_log}" | tail -1)
    parent_sha_of_last=$(sed -rn  's#.*repackaged-(.*)-created-on.*#\1#p' \
                             <<< "${last_deployed_ear}")
    # If the user didn't pass any EAR to repackage, we want, if
    # possible, to pick the previous EAR and re-package that. This is
    # because we want to be able to make apt-get
    # install/upgrade/remove idempotent, not to repackage a repackaged
    # EAR.
    if [ -n "${parent_sha_of_last}" ]; then
      parent_ear_of_last=$(awk "{if (\$8 == \"${parent_sha_of_last}\") print \$7;}" \
                               "${deployment_log}")
      if [ -z "${parent_ear_of_last}" ]; then
        parent_ear_of_last="does--not--exist"
      fi

      file=${cache_dir}/${parent_ear_of_last}
      if [ -r "${file}" ]; then
        print_and_log "Repackaging EAR ${parent_sha_of_last}
          (parent of last deployment) ... "
        ear_name_or_hash="${parent_sha_of_last}"
        file_or_uri=${file}
        return
      fi
    fi

    # If we couldn't find the parent of the previous deployment, try
    # to use the previously deployed EAR.
    local file=${cache_dir}/${last_deployed_ear}
    if [[ -z "${ear_name_or_hash}" && -r "${file}" ]]; then
      print_and_log "Repackaging EAR ${last_deployed_ear}
        (last deployment) ... "
      ear_name_or_hash=${last_deployed_hash}
      file_or_uri=${file}
      return
    else
      print_and_log "
        Will NOT repackage: I couldn't find a previously deployed EAR
        and you didn't specify an EAR to be repackaged using --file
        <ear> or --uri <ear>."
      return 1
    fi

  elif [ -r "${default_cached_engine_ear}" ]; then
    print_and_log "Repackaging EAR ${default_cached_engine_ear} ... "
    file_or_uri=${default_cached_engine_ear}
    ear_name_or_hash=${default_cached_engine_ear##*/}
  else
    print_and_log "
      Will NOT repackage: You must either specify an EAR to be
      repackaged using --file <ear> or --uri <ear>, or the previously
      deployed EAR must be available in ${cache_dir}."
    return 1
  fi
}

## $1 :: file_or_uri
get_local_ear_reference() {
  local file_or_uri=$1

  if [ -f "${file_or_uri}" ]; then
    echo "${file_or_uri}"
  else
    export wget_auth=${wget_builder_auth-""}

    local file_name=
    file_name=${file_or_uri##*/}

    download_uri_target_to_dir "${file_or_uri}" "${cache_dir}" "${file_name}"

    echo "${cache_dir}/${file_name}"
  fi
}

## $1 : WAR to update
## $2 : directories whose contents should be merged with that of the
##      WAR. If any of these contain the same JARs as the WAR has, the
##      version in the directory will take precedence.
merge_all_dirs_to_war() {
  local war=$1
  local dir_list=${*:2}
  debug "Merging all ${war##*/}s ..."

  if [ ! -e "${war}" ]; then
    print_and_log "${war} doesn't exist 💀
      (perhaps you need to install the escenic-content-engine package ?)"
    remove_pid_and_exit_in_error
  fi

  local tmp_dir=
  tmp_dir=$(mktemp -d)
  run unzip -q "${war}" -d "${tmp_dir}"

  local dir=
  for dir in ${dir_list}; do
    if [ ! -d "${dir}/webapp" ]; then
      continue
    fi

    ## Look through all files, JARs and others, and see if they should
    ## overwrite what's in the ${war} variable.
    for f in $(find "${dir}" -type f); do
      # Using builtin BASH string manipulation to save subshell
      # calls. Need two steps to get a subset of the dir path.
      local dir_inside_webapp=${f##*webapp/}
      dir_inside_webapp=${dir_inside_webapp%/*}

      local file_name="${f##*/}"
      local file_suffix="${file_name##*.}"
      local dir_inside_war="${tmp_dir}/${dir_inside_webapp}"

      ## the the exploded WAR doesn't contain the file at all, create
      ## the directory and copy the file.
      if [ ! -d "${dir_inside_war}" ]; then
        run mkdir -p "${dir_inside_war}"
        run cp "${f}" "${dir_inside_war}"
      else
        # ok, so the WAR contains the directory of the current file
        # being checked. Let's see if the WAR has (a different version
        # of) that file.
        local package_file_base=
        package_file_base=$(get_file_base "${f}" "${file_suffix}")

        local file_in_war=
        for file_in_war in $(find "${dir_inside_war}" -type f); do
          local file_in_war_name="${file_in_war##*/}"
          local file_in_war_suffix="${file_in_war_name##*.}"

          local file_in_war_base=
          file_in_war_base=$(get_file_base "${file_in_war}" "${file_in_war_suffix}")

          if [[ "${package_file_base}" == "${file_in_war_base}" &&
                  "${file_suffix}" == "${file_in_war_suffix}" ]]; then
            debug "Removing ${file_in_war} from ${war##*/} since" \
                  "a different version exists in ${f}."
            run rm "${file_in_war}"
          fi
        done

        # Finally, copy the JAR from the package to the appropriate
        # place in the WAR tmp dir.
        debug "Adding ${f} to ${war##*/}"
        run cp "${f}" "${dir_inside_war}"
      fi
    done
  done

  run jar cf "${war}" -C "${tmp_dir}" .
  run rm -r "${tmp_dir}"
}

## Updates studio.war with available studio plugins
##
## $1 : studio WAR to update
## $2 : studio plugin directories
merge_all_plugins_with_studio_war() {
  local war=$1
  local dir_list=${*:2}

  if [ ! -e "${war}" ]; then
    print_and_log "${war} doesn't exist 💀
      (perhaps you need to install the escenic-content-engine package ?)"
    remove_pid_and_exit_in_error
  fi

  local dir=
  for dir in ${dir_list}; do
    log "Adding studio plugin in ${dir} ..."
    local plugin_name=
    plugin_name=$(basename "${dir%/*}")
    # our packages are called escenic-<plugin-name>, removing the prefix
    plugin_name=${plugin_name//escenic[-]}

    local tmp_dir=
    tmp_dir=$(mktemp -d)
    run unzip -q "${war}" -d "${tmp_dir}"
    local plugin_dir_in_war="${tmp_dir}/studio/plugin/${plugin_name}/lib"
    run mkdir -p "${plugin_dir_in_war}"

    # Check if any of the files in dir exist with a different
    # version in the target dir.
    local file=
    for file in $(find "${dir}" -type f); do
      local file_suffix=${file##*.}
      local file_base=
      file_base=$(get_file_base "${file}" "${file_suffix}")

      find "${plugin_dir_in_war}" \
           -maxdepth 1 \
           -type f \
           -name "${file_base}*${file_suffix}" \
           -delete
      run cp "${file}" "${plugin_dir_in_war}/."
    done

    # to be sure it's prestine, we delete the old war
    run rm "${war}"
    (
      cd "${tmp_dir}" || exit 1
      run zip --recurse-paths --quiet "${war}" .
    )

    rm -r "${tmp_dir}"
  done
}

## $1 :: tmp dir with EAR contents
merge_all_webservice_extension_webapps() {
  local tmp_dir=$1
  local war=${tmp_dir}/webservice-extensions.war
  if [ ! -e "${war}" ]; then
    ## The EAR doesn't contain the war, copy it from the installed
    ## package.
    run cp "$(get_installed_package_webservice_extensions_war)" "${war}"
  fi
  merge_all_dirs_to_war \
    "${war}" \
    "$(get_installed_packages_webservice_extensions_list)"
}

## $1 :: tmp dir with EAR contents
merge_all_webservice_webapps() {
  local tmp_dir=$1
  local war=${tmp_dir}/webservice.war
  if [ ! -e "${war}" ]; then
    ## The EAR doesn't contain the war, copy it from the installed
    ## package.
    run cp "$(get_installed_package_webservice_war)" "${war}"
  fi
  merge_all_dirs_to_war \
    "${war}" \
    "$(get_installed_packages_webservice_list)"
}

## $1 :: top dog WAR Takes precendence when there are libraries in
##       both WARs. e.g. ECE's webservice.war
##
## $2 :: under dog WAR. e.g. the EAR's webservice.war. The file will
##       be replaced with a ready patched WAR based on the top dog
##       WAR, with additions in the EAR's webservice.war
merge_wars_let_first_one_win() {
  local topdog_war=$1
  local underdog_war=$2

  log "Replacing ${underdog_war##*/} in the EAR with ${topdog_war}" \
      "just adding unique files from the version of the WAR inside" \
      "the EAR."
  local topdog_tmp_dir=
  topdog_tmp_dir=$(mktemp -d)
  local underdog_tmp_dir=
  underdog_tmp_dir=$(mktemp -d)

  run unzip -q "${topdog_war}" -d "${topdog_tmp_dir}"
  run unzip -q "${underdog_war}" -d "${underdog_tmp_dir}"

  local topdog_file=
  local underdog_file=
  local topdog_file_base=
  local underdog_file_base=

  # Remove any underdog file that topdog has a (different) version
  # of. What's left in the underdog WAR will be added to the
  # uppderog WAR, see below.
  find "${topdog_tmp_dir}" -type f | while read topdog_file; do
    local topdog_basename=${topdog_file##*/}
    local topdog_file_suffix=${topdog_file##*.}
    local topdog_dirname=${topdog_file%/*}
    topdog_dirname=${topdog_dirname//${topdog_tmp_dir}}
    topdog_file_base=$(get_file_base "${topdog_basename}" "${topdog_file_suffix}")

    find "${underdog_tmp_dir}/${topdog_dirname}" \
         -maxdepth 1 \
         -name "${topdog_file_base}*${topdog_file_suffix}" \
         -delete
  done

  # Use the topdog WAR as base and add any file from underdog WAR that
  # the topdog doesn't have. The common libraries (but different
  # version) has been removed in the foor loop above.
  local tmp_result_war="${underdog_war}".tmp
  run cp "${topdog_war}" "${tmp_result_war}"
  (
    cd "${underdog_tmp_dir}" || exit 1
    zip -q -r -u "${tmp_result_war}" . || {
      # see 'man zip' for more details
      if [ $? -eq 12 ]; then
        log "${tmp_result_war} already contained the contents of ${underdog_tmp_dir}"
      else
        remove_pid_and_exit_in_error
      fi
    }
  )

  run cp "${tmp_result_war}" "${underdog_war}"
  run rm "${tmp_result_war}"
  run rm -r "${underdog_tmp_dir}"
  run rm -r "${topdog_tmp_dir}"
}

## $1 :: tmp dir with EAR contents
merge_all_studio_plugins() {
  local tmp_dir=$1
  local war=${tmp_dir}/studio.war
  if [ ! -e "${war}" ]; then
    ## The EAR doesn't contain the war, copy it from the installed
    ## package.
    cp "$(get_installed_package_studio_war)" "${war}"
  fi
  merge_all_plugins_with_studio_war \
    "${war}" \
    "$(get_installed_packages_studio_list)"
}

exit_if_no_os_packages_are_installed() {
  local packages_installed=
  packages_installed=$(
    find -L "${USR_SHARE_DIR}" -maxdepth 1 -name "escenic-*"  -type d | wc -l)

  if [ "${packages_installed}" -eq 0 ]; then
    print_and_log "No escenic packages installed on ${HOSTNAME} ☹"
    remove_pid_and_exit_in_error
  fi
}

## Returns 0 if the passed WAR should be merged with that of the
## package installed version.
##
## $1 :: The war, with full path or just file name. Only the basename
##       will of the war will be compared.
should_merge_package_war() {
  local war=$1

  if [ ! -e "${war}" ]; then
    return 1
  fi

  declare -a should_be_merged_list=(
    "webservice.war"
    "webservice-extensions.war"
    "studio.war"
  )

  local el=
  for el in "${should_be_merged_list[@]}"; do
    if [[ "${war##*/}" == "${el}"  ]]; then
      return 0
    fi
  done

  return 1
}

merge_or_overwrite_webapps_provided_by_packages() {
  local tmp_dir=$1

  local package_war_list=
  package_war_list=$(get_installed_packages_war_list)

  local package_war=
  for package_war in ${package_war_list}; do
    local war_name=${package_war##*/}
    local ear_war="${tmp_dir}/${war_name}"

    if should_merge_package_war "${package_war}"; then
      merge_wars_let_first_one_win "${package_war}" "${ear_war}"
    else
      log "Overwriting WAR in EAR with ${package_war} ..."
      run cp "${package_war}" "${tmp_dir}"
    fi
  done
}

## $1 :: string to be printed (what was being profile)
## $2 :: start time, seconds since epoch, as in $(date +%s)
log_profile() {
  local what=$1
  local start_time=$2
  log "Profiling: ${what} took $(($(date +%s) - start_time)) seconds"
}

## $1 :: EAR file or URI
repackage() {
  local ear=
  local file_or_uri=$1

  exit_if_no_os_packages_are_installed

  if [[ "${type}" != "engine" ]]; then
    print_and_log \
      "Doesn't make sense to repackge ${type} instances →" \
      "not repackaging EAR for ${instance}"
    return
  fi

  ensure_ear_reference_and_lineage_sanity "${file_or_uri}" || {
    return
  }
  ear=$(get_local_ear_reference "${file_or_uri}")

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  print "Repackaging ${ear} with OS package installed JARs and WARs ..."
  start_time=$(date +%s)

  local method_start=

  method_start=$(date +%s)
  extract_archive "${ear}" "${tmp_dir}"
  log_profile "extract_archive ${ear}" "${method_start}"

  method_start=$(date +%s)
  remove_libs_included_in_installed_packages "${tmp_dir}"
  log_profile "remove_libs_included_in_installed_packages" "${method_start}"

  method_start=$(date +%s)
  copy_libs_included_in_installed_packages "${tmp_dir}"
  log_profile "copy_libs_included_in_installed_packages" "${method_start}"

  method_start=$(date +%s)
  merge_all_webservice_extension_webapps "${tmp_dir}"
  log_profile "merge_all_webservice_extension_webapps" "${method_start}"

  method_start=$(date +%s)
  merge_all_webservice_webapps "${tmp_dir}"
  log_profile "merge_all_webservice_webapps" "${method_start}"

  method_start=$(date +%s)
  merge_all_studio_plugins "${tmp_dir}"
  log_profile "merge_all_studio_plugins" "${method_start}"

  method_start=$(date +%s)
  merge_or_overwrite_webapps_provided_by_packages "${tmp_dir}"
  log_profile "merge_or_overwrite_webapps_provided_by_packages" "${method_start}"

  method_start=$(date +%s)
  overwrite_webapp_libs "${tmp_dir}"
  log_profile "overwrite_webapp_libs" "${method_start}"

  # The ${file} variable is used by deploy.sh::deploy()
  export file=$(
    create_new_ear_in_dir \
      /tmp \
      "${tmp_dir}" \
      "${ear_name_or_hash}")

  log "Deleting ${tmp_dir} ..."
  run rm -rf "${tmp_dir}"

  local took=
  took=$(($(date +%s) - start_time))
  print_and_log "Repackaging ${ear} took ${took} seconds,
                 new EAR created: ${file}"
}
