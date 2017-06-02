#! /usr/bin/env bash

# by torstein@escenic.com

test_can_get_base_name_of_develop_snapshot_dependency() {
  local file=base-develop-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_trunk_snapshot_dependency() {
  local file=base-trunk-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_snapshot_dependency() {
  local file=base-2.0-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_regular_major_minor_dependency() {
  local file=base-2.0.1.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_date_stamp_version() {
  local file=relaxngDatatype-20020414.jar
  local expected=relaxngDatatype
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_regular_major_minor_dependency_with_build_number() {
  local file=base-2.0.1-23.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_alpha_dependency() {
  local file=base-2.0.4-alpha-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-beta-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-rc-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_alpha_dependency_semver() {
  local file=base-2.0.4-alpha.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-beta.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-rc.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} .jar)
  assertEquals "${expected}" "${actual}"
}

test_can_detect_that_escenic_admin_doesnt_need_patching() {
  local expected=1
  local actual=
  should_patch_war "/path/to/escenic-admin.war" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"
}

test_can_detect_that_live_center_need_patching() {
  local expected=0
  local actual=
  should_patch_war "/path/to/live-center.war" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"
}

test_can_repackage_an_ear() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)
  local expected=0
  local actual=
  test -f "${repackaged_ear}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"
}

test_can_patch_war_inside_ear() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local ear_extract_tmp_dir=
  ear_extract_tmp_dir=$(mktemp -d)
  (cd "${ear_extract_tmp_dir}" && jar xf "${repackaged_ear}")

  for war in "${ear_extract_tmp_dir}"/*.war; do
    skip=0
    for ece_war in $(get_ece_package_webapp_names); do
      if [[ $(basename "${war}") == "${ece_war}" ]]; then
        skip=1
        break
      fi
    done
    if [ "${skip-0}" -eq 1 ]; then
      continue
    fi

    for ele in $(get_ece_package_template_files); do
      local expected=1
      local actual=
      actual=$(unzip -v "${war}" | grep -c "${ele}")
      assertEquals "${expected}" "${actual}"
    done
  done
  rm -r "${ear_extract_tmp_dir}"
}

test_can_merge_webservice_war_in_ear_keep_extensions_only_in_ear() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local ear_extract_tmp_dir=
  ear_extract_tmp_dir=$(mktemp -d)
  (cd "${ear_extract_tmp_dir}" && jar xf "${repackaged_ear}")

  local expected=1
  actual=$(
    unzip -v "${ear_extract_tmp_dir}/webservice.war" |
      grep -c "${EAR_WEBSERVICE_WAR_EXTENSION_FILE}")
  assertEquals "${expected}" "${actual}"
}

test_can_keep_lib_extension_only_in_ear() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local expected=1
  actual=$(
    unzip -v "${repackaged_ear}" |
      grep -c "${EAR_LIB_EXTENSION_FILE}")
  assertEquals "${expected}" "${actual}"
}

test_can_merge_webservice_war_in_ear_replace_libraries_present_on_machine() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local ear_extract_tmp_dir=
  ear_extract_tmp_dir=$(mktemp -d)
  (cd "${ear_extract_tmp_dir}" && jar xf "${repackaged_ear}")

  local expected=0
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "engine-servletsupport-${ECE_VERSION_IN_EAR}")
  assertEquals "Version in EAR should be replaced with package version" \
               "${expected}" \
               "${actual}"

  local expected=1
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "engine-servletsupport-${ECE_VERSION}")
  assertEquals "Version in EAR should be replaced with package version" \
               "${expected}" \
               "${actual}"
}

test_can_repackage_ear_no_duplicates_in_lib() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local expected=1
  local actual=
  actual=$(unzip -v "${repackaged_ear}" | grep -c engine-core)
  assertEquals "${expected}" "${actual}"
}

get_ece_package_template_files() {
  cat <<EOF
WEB-INF/lib/common-nursery-servlet-${ECE_VERSION}.jar
WEB-INF/lib/engine-presentation-${ECE_VERSION}.jar
WEB-INF/lib/engine-servletsupport-${ECE_VERSION}.jar
WEB-INF/lib/engine-taglib-${ECE_VERSION}.jar
WEB-INF/lib/jcaptcha-all-1.0-RC5.jar
WEB-INF/lib/recaptcha4j-0.0.7.jar
WEB-INF/lib/servlet-3.3.jar
EOF
}

get_ece_package_webapp_names() {
  cat <<EOF
studio.war
webservice.war
webservice-extensions.war
EOF
}

## $1 :: tmp dir in which to create the package installation
create_ece_package_installation() {
  local tmp_dir=$1

  export USR_SHARE_DIR="${tmp_dir}/escenic"
  local ece_share_dir="${USR_SHARE_DIR}/escenic-content-engine-6.0"
  mkdir -p "${ece_share_dir}/webapps"
  for el in $(get_ece_package_webapp_names); do
    (
      local a_tmp_dir=
      a_tmp_dir=$(mktemp -d)
      cd "${a_tmp_dir}" && jar cf "${ece_share_dir}/webapps/${el}" .
      rm -r "${a_tmp_dir}"
    )
  done

  local ece_lib_dir="${ece_share_dir}/lib"
  mkdir -p "${ece_lib_dir}"
  touch "${ece_lib_dir}/engine-core-${ECE_VERSION}.jar"

  local ece_template_dir="${ece_share_dir}/template"
  mkdir -p "${ece_template_dir}"
  for el in $(get_ece_package_template_files); do
    local dir="${ece_template_dir}/$(dirname "${el}")"
    mkdir -p "${dir}"
    # create jar
    local jar="${dir}/$(basename "${el}")"
    local f_tmp_dir=
    f_tmp_dir=$(mktemp -d)
    (cd "${f_tmp_dir}" && jar cf "${jar}" .)
    rm -r "${f_tmp_dir}"
  done
}

create_ear_that_will_be_repackaged() {
  local ear_dir="${tmp_dir}/ear"
  mkdir "${ear_dir}"

  EAR_LIB_EXTENSION_FILE=
  EAR_LIB_EXTENSION_FILE=global-lib-extension.file

  local ear_lib_dir="${ear_dir}/lib"
  mkdir "${ear_lib_dir}"
  touch "${ear_lib_dir}/engine-core-${ECE_VERSION_IN_EAR}.jar"
  touch "${ear_lib_dir}/${EAR_LIB_EXTENSION_FILE}"

  # create a pub war
  local war="${ear_dir}/${FUNCNAME[0]}.war"
  local war_tmp_dir=
  war_tmp_dir=$(mktemp -d)
  (cd "${war_tmp_dir}" && jar cf "${war}" .)
  rm -r "${war_tmp_dir}"

  # create webservice war
  EAR_WEBSERVICE_WAR_EXTENSION_FILE=
  EAR_WEBSERVICE_WAR_EXTENSION_FILE=webservice-war-extension.file
  war="${ear_dir}/webservice.war"
  war_tmp_dir=$(mktemp -d)
  touch "${war_tmp_dir}/${EAR_WEBSERVICE_WAR_EXTENSION_FILE}"
  mkdir -p "${war_tmp_dir}/WEB-INF/lib"
  touch "${war_tmp_dir}/WEB-INF/lib/engine-servletsupport-${ECE_VERSION_IN_EAR}.jar"
  (cd "${war_tmp_dir}" && jar cf "${war}" .)
  rm -r "${war_tmp_dir}"

  ear="${tmp_dir}/${BASH_SOURCE[0]}.ear"
  (cd "${ear_dir}" && jar cf "${ear}" .)
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece.d/repackage.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-bashing.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-io.sh"
  log=/tmp/${BASH_SOURCE[0]}.$$.log

  tmp_dir=$(mktemp -d)
  cache_dir=${tmp_dir}/var/lib/escenic
  data_dir=${tmp_dir}/var/lib/escenic
  log_dir=${tmp_dir}/var/log/escenic
  run_dir=${tmp_dir}/var/run/escenic

  ECE_VERSION=6.7.5
  ECE_VERSION_IN_EAR=6.2.0
  create_ece_package_installation "${tmp_dir}"
  create_ear_that_will_be_repackaged "${tmp_dir}"
}

## @override shunit2
tearDown() {
  rm -r "${tmp_dir}"
}

main() {
  . "$(dirname "$0")"/shunit2/source/2.1/src/shunit2
}

main "$@"
