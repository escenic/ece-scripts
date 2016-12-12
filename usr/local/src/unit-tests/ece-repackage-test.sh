#! /usr/bin/env bash

# by torstein@escenic.com

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


## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece.d/repackage.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/source/2.1/src/shunit2
}

main "$@"
