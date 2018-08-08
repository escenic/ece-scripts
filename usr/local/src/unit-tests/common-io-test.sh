#! /usr/bin/env bash
## author: mah@escenic.com

test_can_determine_make_dir_works_with_space() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local file_path="${tmp_dir}/test website"
  local expected=0
  local actual=
  make_dir ${file_path} && actual=$? || actual=$?
  rm -rf ${tmp_dir}
  assertEquals "Can determine make_dir works with space" "${expected}" "${actual}"
}

test_can_determine_make_dir_works_without_space() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)
  local file_path="${tmp_dir}/testwebsite"
  local expected=0
  local actual=
  make_dir ${file_path} && actual=$? || actual=$?
  rm -rf ${tmp_dir}
  assertEquals "Can determine make_dir works without space" "${expected}" "${actual}"
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
