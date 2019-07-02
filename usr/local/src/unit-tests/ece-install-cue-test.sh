#! /usr/bin/env bash

## author: torstein@escenic.com

test_can_get_cue_conf_dir_when_usr_and_etc_base_dir_are_different() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)

  local cue_dir=/usr/share/escenic/cue-web-3.2
  mkdir -p "${tmp_dir}${cue_dir}"

  local cue_conf_dir=/etc/escenic/cue-web
  mkdir -p "${tmp_dir}${cue_conf_dir}"

  local expected="${tmp_dir}/etc/escenic/cue-web"
  local actual=
  actual=$(_cue_get_conf_dir "${cue_dir}" "${tmp_dir}/etc/escenic")
  assertEquals "Can get new cue-web etc dir" "${expected}" "${actual}"

  rm -rf "${tmp_dir}"
}

test_can_get_cue_conf_dir_when_usr_and_etc_base_dir_are_the_same() {
  local tmp_dir=
  tmp_dir=$(mktemp -d)

  local cue_dir=/usr/share/escenic/cue-web-3.2
  mkdir -p "${tmp_dir}${cue_dir}"

  local cue_conf_dir=/etc/escenic/cue-web-3.2
  mkdir -p "${tmp_dir}${cue_conf_dir}"

  local expected="${tmp_dir}${cue_conf_dir}"
  local actual=
  actual=$(_cue_get_conf_dir "${cue_dir}" "${tmp_dir}/etc/escenic")
  assertEquals "Can get old cue-web etc dir" "${expected}" "${actual}"

  rm -rf "${tmp_dir}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/cue.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-bashing.sh"
  log=/dev/null
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
