#! /usr/bin/env bash

## author: torstein@escenic.com

test_is_hook_ok_to_run() {
  local expected=0
  local cmd=/bin/ls
  _is_hook_ok_to_run "${cmd}"
  local actual=$?
  assertEquals "${cmd} should be a legal hook" "${expected}" "${actual}"
}

test_is_hook_ok_to_run_doesnt_exist() {
  local expected=1
  local cmd=/bin/doesnt/exist
  _is_hook_ok_to_run "${cmd}"
  local actual=$?
  assertEquals "${cmd} shouldn't be a legal hook" "${expected}" "${actual}"
}

test_is_hook_ok_to_run_not_executable() {
  local expected=1
  local cmd=/etc/fstab
  _is_hook_ok_to_run "${cmd}"
  local actual=$?
  assertEquals "${cmd} shouldn't be a legal hook" "${expected}" "${actual}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/hooks.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
