#! /usr/bin/env bash

# by torstein@escenic.com

test_can_install_escenic_packages_when_in_proprietary_mode() {
  export fai_package_only_proprietary=1
  local expected=0
  local actual=

  local package_list="escenic-newsgate-3.2"
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should be installable when in proprietary" \
               "${expected}" "${actual}"

  package_list="vosa-sdp-bootstrapper"
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should be installable when in proprietary" \
               "${expected}" "${actual}"

  package_list="spore"
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should be installable when in proprietary" \
               "${expected}" "${actual}"
}

test_can_not_install_foss_packages_when_in_proprietary_mode() {
  export fai_package_only_proprietary=1
  local package_list="curl wget"

  local expected=1
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "FOSS packages should not be installable when in proprietary" \
               "${expected}" "${actual}"
}

test_can_not_install_escenic_packages_when_in_3rd_party_mode() {
  export fai_package_only_3rd_party=1
  local package_list="escenic-newsgate-3.2"

  local expected=1
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should not be installable when in 3rd party" \
               "${expected}" "${actual}"
}

test_can_install_foss_when_in_3rd_party_mode() {
  export fai_package_only_3rd_party=1
  local package_list="curl wget"

  local expected=0
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should not be installable when in 3rd party" \
               "${expected}" "${actual}"
}

test_will_fail_on_empty_list() {
  export fai_package_only_3rd_party=1
  local package_list=""

  local expected=1
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Should fail with empty list," \
               "${expected}" "${actual}"
}

test_can_not_install_if_one_is_proprietary_when_in_3rd_party_mode() {
  export fai_package_only_3rd_party=1
  local package_list="curl wget escenic-content-engine"

  local expected=1
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals "Escenic packages should not be installable when in 3rd party" \
               "${expected}" "${actual}"
}

test_can_install_all_package_if_neither_install_mode() {
  export fai_package_only_3rd_party=0
  export fai_package_only_proprietary=0
  local package_list="curl wget escenic-content-engine"

  local expected=0
  local actual=
  is_package_list_installable "${package_list}" && actual=$? || actual=$?
  assertEquals \
    "All packages should be installable when neither
    3rd party nor proprietary install mode has been selected," \
      "${expected}" "${actual}"
}


test_using_is_package_list_installable_in_if_test() {
  export fai_package_only_3rd_party=1
  local package_list=escenic

  if ! is_package_list_installable "${package_list}"; then
    :
  fi
  package_list=curl
  if is_package_list_installable "${package_list}"; then
    :
  fi

}

test_is_package_source_only_3rd_party() {
  export fai_package_only_3rd_party=1
  local expected=0
  local actual=

  is_package_source_only_3rd_party && actual=$? || actual=$?
  assertEquals "Package source should be 3rd party," "${expected}" "${actual}"
}

test_is_package_source_only_proprietary() {
  export fai_package_only_proprietary=1
  local expected=0
  local actual=

  is_package_source_only_proprietary && actual=$? || actual=$?
  assertEquals "Package source should be proprietary," "${expected}" "${actual}"
}

## Stub overriding the common-bashing::log function
log() {
  :
}

## @override shunit2
setUp() {
  export fai_package_only_3rd_party=0
  export fai_package_only_proprietary=0

  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/package-based-install.sh"
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
