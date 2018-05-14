#! /usr/bin/env bash

## author: torstein@escenic.com

test_can_get_oracle_tarball_url() {
  local actual=
  actual=$(_java_get_oracle_tarball_url)
  assertNotNull "Should be able to get Oracle URL"  "${actual}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/java.sh"
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
