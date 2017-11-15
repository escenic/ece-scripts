#! /usr/bin/env bash
## author: torstein@escenic.com

test_can_determine_ece6_from_package_enabled_is_true() {
  export fai_package_enabled=1

  local expected=0
  local actual=
  is_installing_post_ece6 && actual=$? || actual=$?
  assertEquals "Cand etermine ECE6 by fai_package_enabled" "${expected}" "${actual}"
}

test_can_determine_ece6_from_download_list_with_61() {
  unset fai_package_enabled
  export technet_download_list="
    engine-6.1.3-234.zip
  "

  local expected=0
  local actual=
  is_installing_post_ece6 && actual=$? || actual=$?
  assertEquals "Cand etermine ECE6 by download list" "${expected}" "${actual}"
}

test_can_determine_ece6_from_download_list_with_57() {
  unset fai_package_enabled
  export technet_download_list="
    engine-5.7.3-234.zip
  "

  local expected=1
  local actual=
  is_installing_post_ece6 && actual=$? || actual=$?
  assertEquals "Cand etermine ECE6 by download list" "${expected}" "${actual}"
}

test_can_determine_ece6_from_package_enabled_is_false() {
  export fai_package_enabled=0

  local expected=1
  local actual=
  is_installing_post_ece6 && actual=$? || actual=$?
  assertEquals "Cand etermine ECE6 by fai_package_enabled" "${expected}" "${actual}"
}

## @OVERRIDE shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-ece.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
