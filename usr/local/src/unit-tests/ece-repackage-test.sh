#! /usr/bin/env bash

# by torstein@escenic.com

test_can_get_base_name_of_develop_snapshot_dependency() {
  local file=/tmp/var/base-develop-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_jar_pack_gz() {
  local file=/tmp/var/base-develop-SNAPSHOT.jar.pack.gz
  local expected=base
  local actual=
  actual=$(get_file_base ${file} gz)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_develop_timestamp_dependency() {
  local file=base-develop-20170126.051354-372.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_trunk_snapshot_dependency() {
  local file=base-trunk-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_snapshot_dependency() {
  local file=base-2.0-SNAPSHOT.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_regular_major_minor_dependency() {
  local file=base-2.0.1.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_date_stamp_version() {
  local file=relaxngDatatype-20020414.jar
  local expected=relaxngDatatype
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_regular_major_minor_dependency_with_build_number() {
  local file=base-2.0.1-23.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_alpha_dependency() {
  local file=base-2.0.4-alpha-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-beta-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-rc-2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_get_base_name_of_alpha_dependency_semver() {
  local file=base-2.0.4-alpha.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-beta.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"

  file=base-2.0.4-rc.2.jar
  local expected=base
  local actual=
  actual=$(get_file_base ${file} jar)
  assertEquals "${expected}" "${actual}"
}

test_can_detect_that_escenic_admin_doesnt_need_patching() {
  local expected=1
  local actual=
  should_patch_war_with_template_libs "/path/to/escenic-admin.war" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"
}

test_can_detect_that_live_center_need_patching() {
  local expected=0
  local actual=
  should_patch_war_with_template_libs "/path/to/live-center.war" && actual=$? || actual=$?
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

## be sure that it uses the webservice.war install with the
## escenic-content-engine-<version> as a basis.
test_can_merge_webservice_war_include_all_files_in_package_war() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local ear_extract_tmp_dir=
  ear_extract_tmp_dir=$(mktemp -d)
  (cd "${ear_extract_tmp_dir}" && jar xf "${repackaged_ear}")

  local expected=0
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "engine-jersey-${ECE_VERSION_IN_EAR}")
  assertEquals "Version of engine-jersey (lib in webservice.war) in EAR should be replaced with package version" \
               "${expected}" \
               "${actual}"

  expected=1
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "engine-jersey-${ECE_VERSION}")
  assertEquals "Version of engine-jersey (lib in webservice.war) in EAR should be replaced with package version" \
               "${expected}" \
               "${actual}"

  expected=1
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "engine-servletsupport-${ECE_VERSION}")
  assertEquals "Version of engine-servletsupport (template lib) in EAR should be replaced with package version" \
               "${expected}" \
               "${actual}"

}

## be sure that it uses the webservice.war install with the
## escenic-content-engine-<version> as a basis.
test_can_merge_webservice_war_replace_plugin_jars() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local ear_extract_tmp_dir=
  ear_extract_tmp_dir=$(mktemp -d)
  (cd "${ear_extract_tmp_dir}" && jar xf "${repackaged_ear}")

  local expected=1
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "plugin-webservice")
  assertEquals "Should only be one plugin-webservice in webservice.war" \
               "${expected}" \
               "${actual}"
  expected=1
  local looking_for=${EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB}-${PACKAGE_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB_VERSION}.jar
  actual=$(unzip -v "${ear_extract_tmp_dir}/webservice.war" |
             grep -c "${looking_for}")
  assertEquals "Didn't find ${looking_for}" "${expected}" "${actual}"
}

test_can_merge_files_with_same_base_but_different_suffix() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  unzip -q "${repackaged_ear}" webservice.war -d "${tmp_dir}"
  local expected=2
  local actual=
  actual=$(unzip -v "${tmp_dir}/webservice.war" |
             grep -c "${EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF}")
  assertEquals "${expected}" "${actual}"

  expected=1
  actual=$(unzip -v "${tmp_dir}/webservice.war" |
             grep -c "${EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF}.css")
  assertEquals "${expected}" "${actual}"

  expected=1
  actual=$(unzip -v "${tmp_dir}/webservice.war" |
             grep -c "${EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF}.pdf")
  assertEquals "${expected}" "${actual}"

  rm -r "${tmp_dir}"
}

## <plugin>/webapps/*.war should get patched with ECE's template libs,
## but not with template libs from other plugins.
test_can_exclude_other_plugin_webapp_libs_when_patching_plugin_package_webapp() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  unzip -q "${repackaged_ear}" "${EAR_PLUGIN2_WEBAPP}".war -d "${tmp_dir}"

  local expected=0
  local actual=
  actual=$(unzip -v "${tmp_dir}/${EAR_PLUGIN2_WEBAPP}.war" |
             grep -c "${EAR_PLUGIN_TEMPLATE_LIB}")
  assertEquals "${expected}" "${actual}"
}

test_can_merge_webapp_extensions_index_jsp() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local tmp_dir=
  tmp_dir=$(mktemp -d)
  unzip -q "${repackaged_ear}" "webservice-extensions.war" -d "${tmp_dir}"

  local expected=1
  local actual=
  actual=$(unzip -v "${tmp_dir}/webservice-extensions.war" |
             grep -c "${WEBSERVICE_EXTENSION_INDEX_JSP_REL_DIR}/index.jsp")
  assertEquals "${expected}" "${actual}"

  expected=${WEBSERVICE_EXTENSION_INDEX_JSP_CONTENTS_PACKAGE}
  unzip -q "${tmp_dir}/webservice-extensions.war" \
        "${WEBSERVICE_EXTENSION_INDEX_JSP_REL_DIR}/index.jsp" \
        -d "${tmp_dir}"
  actual=$(cat "${tmp_dir}/${EAR_PLUGIN_NAME}/datasource/index.jsp")
  assertEquals "${expected}" "${actual}"
}

test_can_merge_studio_pack_gz_files() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  unzip -q "${repackaged_ear}" studio.war -d "${tmp_dir}"

  local expected=0
  local actual=

  actual=$(unzip -v "${tmp_dir}/studio.war" |
             grep -c "studio/lib/studio-core-${ECE_VERSION_IN_EAR}.jar.pack.gz")
  assertEquals "Should merge CS library merged with correct version, no EAR version" \
               "${expected}" \
               "${actual}"

  expected=1
  actual=
  actual=$(unzip -v "${tmp_dir}/studio.war" |
             grep -c "studio/lib/studio-core-${ECE_VERSION}.jar.pack.gz")
  assertEquals "Should merge CS library merged with correct version, include package version" \
               "${expected}" \
               "${actual}"
}

test_can_merge_studio_plugin_libaries_replace_version_ear() {
  local repackaged_ear=
  repackaged_ear=$(quiet=1 repackage "${ear}" | tail -1)

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  unzip -q "${repackaged_ear}" studio.war -d "${tmp_dir}"

  local expected=0
  local actual=

  actual=$(unzip -v "${tmp_dir}/studio.war" |
             grep -c "studio/plugin/${EAR_PLUGIN_NAME}/lib/${EAR_PLUGIN_NAME}-studio-${ECE_VERSION_IN_EAR}.jar")
  assertEquals "Should merge CS plugin library correctly, not version in EAR." \
               "${expected}" \
               "${actual}"

  expected=1
  actual=
  actual=$(unzip -v "${tmp_dir}/studio.war" |
             grep -c "studio/plugin/${EAR_PLUGIN_NAME}/lib/${EAR_PLUGIN_NAME}-studio-${ECE_VERSION}.jar")
  assertEquals "Should merge CS plugin library correctly, package version." \
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
escenic-admin.war
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

  # webservice.war
  local webservice_war_tmp="${tmp_dir}/webservice_tmp"
  mkdir -p "${webservice_war_tmp}/WEB-INF/lib"
  touch "${webservice_war_tmp}/WEB-INF/lib/engine-jersey-${ECE_VERSION}.jar"
  touch "${webservice_war_tmp}/WEB-INF/lib/engine-servletsupport-${ECE_VERSION}.jar"
  touch "${webservice_war_tmp}/WEB-INF/lib/${EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF}.pdf"
  (cd "${webservice_war_tmp}" &&
     zip -q -u -r "${ece_share_dir}/webapps/webservice.war" .)

  # webservice-extensions.war
  local webservice_extensions_war_tmp="${tmp_dir}/webservice_extensions_tmp"
  mkdir -p "${webservice_extensions_war_tmp}/WEB-INF/lib"
  touch "${webservice_extensions_war_tmp}/index.jsp"
  (cd "${webservice_extensions_war_tmp}" &&
     zip -q -u -r "${ece_share_dir}/webapps/webservice-extensions.war" .)

  # studio.war
  local studio_war_tmp="${tmp_dir}/studio_tmp"
  mkdir -p "${studio_war_tmp}/studio/lib"
  touch "${studio_war_tmp}/studio/lib/studio-core-${ECE_VERSION}.jar.pack.gz"
  (cd "${studio_war_tmp}" &&
     zip -q -u -r "${ece_share_dir}/webapps/studio.war" .)

  # global lib
  local ece_lib_dir="${ece_share_dir}/lib"
  mkdir -p "${ece_lib_dir}"
  touch "${ece_lib_dir}/engine-core-${ECE_VERSION}.jar"

  # template lib
  local ece_template_dir="${ece_share_dir}/template"
  mkdir -p "${ece_template_dir}"
  for el in $(get_ece_package_template_files); do
    local dir=
    dir="${ece_template_dir}/$(dirname "${el}")"
    mkdir -p "${dir}"
    # create jar
    local jar=
    jar="${dir}/$(basename "${el}")"
    local f_tmp_dir=
    f_tmp_dir=$(mktemp -d)
    (cd "${f_tmp_dir}" && jar cf "${jar}" .)
    rm -r "${f_tmp_dir}"
  done

  # a plugin
  # - with a JAR to be added to webservice.war
  # - with a JAR to be added to publication webapps
  # - with a JAR to be added to studio.war
  # - with an index.jsp to be added to webservice-extensions.war
  local plugin_share_dir="${USR_SHARE_DIR}/escenic-${EAR_PLUGIN_NAME}"
  local plugin_template_web_inf_lib="${plugin_share_dir}/publication/webapp/WEB-INF/lib"
  local plugin_web_inf_lib="${plugin_share_dir}/webservice/webapp/WEB-INF/lib"
  mkdir -p "${plugin_web_inf_lib}"
  mkdir -p "${plugin_template_web_inf_lib}"
  touch "${plugin_web_inf_lib}/${EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB}-${PACKAGE_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB_VERSION}.jar"
  touch "${plugin_template_web_inf_lib}/${EAR_PLUGIN_TEMPLATE_LIB}.jar"
  local plugin_studio_lib_dir="${plugin_share_dir}/studio/lib"
  mkdir -p "${plugin_studio_lib_dir}"
  touch "${plugin_studio_lib_dir}/${EAR_PLUGIN_NAME}-studio-${ECE_VERSION}.jar"
  export PLUGIN_INDEX_JSP="${plugin_share_dir}/webservice-extensions/webapp/${WEBSERVICE_EXTENSION_INDEX_JSP_REL_DIR}/index.jsp"
  mkdir -p "${PLUGIN_INDEX_JSP%/*}"
  echo "${WEBSERVICE_EXTENSION_INDEX_JSP_CONTENTS_PACKAGE}" > "${PLUGIN_INDEX_JSP}"

  # another plugin
  # - with a JAR to be added to studio.war
  plugin_share_dir="${USR_SHARE_DIR}/escenic-${EAR_PLUGIN2_NAME}"
  plugin_webapps_dir="${plugin_share_dir}/webapps"
  mkdir -p "${plugin_webapps_dir}"
  local plugin_ws_tmp_dir=
  plugin_ws_tmp_dir=$(mktemp -d)
  (cd "${plugin_ws_tmp_dir}" && jar cf "${plugin_webapps_dir}/${EAR_PLUGIN2_WEBAPP}.war" .)
  rm -r "${plugin_ws_tmp_dir}"
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
  touch "${war_tmp_dir}/WEB-INF/lib/engine-jersey-${ECE_VERSION_IN_EAR}.jar"
  touch "${war_tmp_dir}/WEB-INF/lib/${EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB}-${EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB_VERSION}.jar"
  touch "${war_tmp_dir}/WEB-INF/lib/${EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF}.css"
  (cd "${war_tmp_dir}" && jar cf "${war}" .)
  rm -r "${war_tmp_dir}"

  # create webservice-extensions.war
  war_tmp_dir=$(mktemp -d)
  local index_jsp_in_we_war="${war_tmp_dir}/${WEBSERVICE_EXTENSION_INDEX_JSP_REL_DIR}/index.jsp"
  mkdir -p "${index_jsp_in_we_war%/*}"
  echo "${WEBSERVICE_EXTENSION_INDEX_JSP_CONTENTS_EAR}" > "${index_jsp_in_we_war}"
  (cd "${war_tmp_dir}" && jar cf "${ear_dir}/webservice-extensions.war" .)
  rm -r "${war_tmp_dir}"

  # create studio.war
  war_tmp_dir=$(mktemp -d)
  local studio_lib_dir="${war_tmp_dir}/studio/lib"
  mkdir -p "${studio_lib_dir}"
  touch "${studio_lib_dir}/studio-core-${ECE_VERSION_IN_EAR}.jar.pack.gz"
  mkdir -p "${war_tmp_dir}/studio/plugin/${EAR_PLUGIN_NAME}/lib"
  touch "${war_tmp_dir}/studio/plugin/${EAR_PLUGIN_NAME}/lib/${EAR_PLUGIN_NAME}-studio-${ECE_VERSION_IN_EAR}.jar"

  war="${ear_dir}/studio.war"
  (cd "${war_tmp_dir}" && jar cf "${war}" .)
  rm -r "${war_tmp_dir}"

  ear="${tmp_dir}/$(basename "$0").ear"
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

  EAR_PLUGIN_NAME=foo-some-plugin
  EAR_PLUGIN2_NAME=bar-some-other-plugin
  EAR_PLUGIN2_WEBAPP=${EAR_PLUGIN2_NAME}-ws

  WEBSERVICE_EXTENSION_INDEX_JSP_REL_DIR=${EAR_PLUGIN_NAME}/datasource
  WEBSERVICE_EXTENSION_INDEX_JSP_CONTENTS_PACKAGE="<h1>hello from package</h1>"
  WEBSERVICE_EXTENSION_INDEX_JSP_CONTENTS_EAR="<h2>Hello from ear</h2>"

  EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB=${EAR_PLUGIN_NAME}-webservice-lib
  EAR_PLUGIN_TEMPLATE_LIB=${EAR_PLUGIN_NAME}-presentation
  EAR_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB_VERSION=1.2.3
  EAR_WEBSERVICE_WAR_FILE_BOTH_CSS_AND_PDF=hello-world
  PACKAGE_WEBSERVICE_WAR_PLUGIN_WEBSERVICE_LIB_VERSION=5.3.1

  create_ece_package_installation "${tmp_dir}"
  create_ear_that_will_be_repackaged "${tmp_dir}"
}

## @override shunit2
tearDown() {
  rm -r "${tmp_dir}"
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
