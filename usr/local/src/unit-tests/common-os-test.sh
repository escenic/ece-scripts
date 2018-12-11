#! /usr/bin/env bash
## author: torstein@escenic.com

test_can_get_tomcat_download_url_should_not_get_fallback() {
  unset tomcat_download
  local actual=
  actual=$(get_tomcat_download_url)

  assertNotEquals "Shouldn't get the fallback url" "${fallback_tomcat_url}" "${actual}"
}

test_can_get_secondary_interfaces_doesnt_contain_docker() {
  local actual=
  actual=$(get_secondary_interfaces | grep -c docker)
  assertEquals "Doesn't contain docker devices" 0 "${actual}"
}

test_can_get_secondary_interfaces_doesnt_contain_loopback_device() {
  local actual=
  actual=$(get_secondary_interfaces | grep -c -w lo)
  assertEquals "Doesn't contain loopback device" 0 "${actual}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-os.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
