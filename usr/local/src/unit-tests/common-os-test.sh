#! /usr/bin/env bash
## author: torstein@escenic.com

test_can_get_tomcat_download_url_should_not_get_fallback() {
  unset tomcat_download
  local actual=
  actual=$(get_tomcat_download_url)

  assertNotEquals "Shouldn't get the fallback url" "${fallback_tomcat_url}" "${actual}"
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
  . "$(dirname "$0")"/shunit2/source/2.1/src/shunit2
}

main "$@"
