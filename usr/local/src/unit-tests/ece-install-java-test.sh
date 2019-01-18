#! /usr/bin/env bash

## author: torstein@escenic.com

test_can_get_oracle_tarball_url() {
  local actual=
  actual=$(_java_get_oracle_tarball_url)
  assertNotNull "Should be able to get Oracle URL"  "${actual}"
}

test_can_get_oracle_rpm_url() {
  local actual=
  actual=$(_java_get_oracle_rpm_url)
  assertNotNull "Should be able to get Oracle RPM URL"  "${actual}"
  assertTrue "[[ ${actual} == http*rpm ]]"
}

test_can_get_java_spec_version() {
  javac=/usr/lib/jvm/oracle-java8-jdk-amd64/bin/javac
  expected=1.8
  actual=$(echo "${javac}" | _java_get_spec_version)
  assertNotNull "${actual}"
  assertEquals "Should get Java spec version" "${expected}" "${actual}"
}

test_java_spec_1_8_is_ok() {
  local expected=0
  echo 1.8 | _java_is_spec_supported && actual=$? || actual=$?
  assertEquals "Java spec 1.8 is ok" "${expected}" "${actual}"
}

test_java_spec_9_is_ok() {
  local expected=0
  echo 9 | _java_is_spec_supported && actual=$? || actual=$?
  assertEquals "Java spec 9 is ok" "${expected}" "${actual}"
}

test_java_spec_10_is_ok() {
  local expected=0
  echo 10 | _java_is_spec_supported && actual=$? || actual=$?
  assertEquals "Java spec 10 is ok" "${expected}" "${actual}"
}

test_java_spec_11_is_ok() {
  local expected=0
  echo 11 | _java_is_spec_supported && actual=$? || actual=$?
  assertEquals "Java spec 11 is ok" "${expected}" "${actual}"
}

test_has_java_installed() {
  local expected=0
  has_java_installed && actual=$? || actual=$?
  assertEquals "Java should be installed" "${expected}" "${actual}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/java.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-bashing.sh"
  log=/dev/null
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
