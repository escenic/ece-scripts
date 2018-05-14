#! /usr/bin/env bash

# by torstein@escenic.com

test_can_read_version() {
  local ece_scripts_version=1.2.3
  local expected="Version: ${ece_scripts_version}"

  local actual=
  actual=$(read_user_input "--version")
  assertEquals "Should reply with version," "${expected}" "${actual}"

  actual=""
  actual=$(read_user_input "-V")
  assertEquals "Should reply with version," "${expected}" "${actual}"
}

test_can_set_verbose() {
  local expected=1

  export debug=0
  read_user_input "--verbose"
  local actual=${debug}
  assertEquals "Should set verbose," "${expected}" "${actual}"

  export debug=0
  read_user_input "-v"
  local actual=${debug}
  assertEquals "Should set verbose," "${expected}" "${actual}"
}

test_can_set_only_3rd_party() {
  local expected=1

  read_user_input "--only-3rd-party"
  local actual=${fai_package_only_3rd_party}

  assertEquals "Can set only 3rd party flag," "${expected}" "${actual}"
}

test_can_set_only_proprietary() {
  local expected=1

  read_user_input "--only-proprietary"
  local actual=${fai_package_only_proprietary}

  assertEquals "Can set only proprietary flag," "${expected}" "${actual}"
}


test_can_set_only_3rd_party_conf_file_at_the_same_time() {
  local expected=1

  # This is the internal variable used in ece-install
  export conf_file="invalid"

  local passed_conf_file=/etc/foo.yaml

  read_user_input "--only-3rd-party" "-f" "${passed_conf_file}"
  local actual=${fai_package_only_3rd_party}
  assertEquals "Can set only 3rd party flag and conf at the same time," \
               "${expected}" "${actual}"

  expected=${passed_conf_file}
  actual=${conf_file}
  assertEquals "Can set only 3rd party flag and conf at the same time," \
               "${expected}" "${actual}"
}

test_can_read_conf_file() {
  local passed_conf_file=/etc/foo.yaml
  local expected=${passed_conf_file}

  # This is the internal variable used in ece-install
  export conf_file="invalid"

  read_user_input "-f" "${passed_conf_file}"
  local actual=${conf_file}
  assertEquals "Should set passed conf file," "${expected}" "${actual}"

  export conf_file="invalid"
  read_user_input "--conf-file" "${passed_conf_file}"
  local actual=${conf_file}
  assertEquals "Should set passed conf file," "${expected}" "${actual}"
}


## @override shunit2
setUp() {
  export fai_package_only_3rd_party=0
  export fai_package_only_proprietary=0
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/user-input.sh"
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
