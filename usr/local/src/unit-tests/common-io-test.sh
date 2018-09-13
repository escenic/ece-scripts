#! /usr/bin/env bash
## author: mah@escenic.com

test_can_determine_make_dir_works_with_space() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local file_path="${tmp_dir}/test website"
  local expected=0
  local actual=
  make_dir "${file_path}" && actual=$? || actual=$?
  assertEquals "Can determine make_dir works with space (call)" "${expected}" "${actual}"

  ls "${file_path}" &>/dev/null  && actual=$? || actual=$?
  assertEquals "Can list results of make_dir with names with space " "${expected}" "${actual}"

  rm -rf ${tmp_dir}
}

test_can_determine_make_dir_works_without_space() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local file_path="${tmp_dir}/testwebsite"
  local expected=0
  local actual=
  make_dir "${file_path}" && actual=$? || actual=$?
  rm -rf ${tmp_dir}
  assertEquals "Can determine make_dir works without space" "${expected}" "${actual}"
}

test_can_create_multiple_directories () {
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local file_path="${tmp_dir}/testwebsite"
  local file_path2="${tmp_dir}/another-website"
  local expected=0
  local actual=
  make_dir ${file_path} ${file_path2} && actual=$? || actual=$?
  assertEquals "Can create multiple directories" "${expected}" "${actual}"

  ls "${file_path}" &>/dev/null  && actual=$? || actual=$?
  assertEquals "Can create multiple directories" "${expected}" "${actual}"
  ls "${file_path2}" &>/dev/null  && actual=$? || actual=$?
  assertEquals "Can create multiple directories" "${expected}" "${actual}"

  rm -rf ${tmp_dir}
}

## @OVERRIDE shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-bashing.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-io.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
