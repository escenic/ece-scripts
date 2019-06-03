#! /usr/bin/env bash

# by mogsie@escenic.com

test_apply_conf_can_get_from_ini_file() {
  local file="
[foo]
b = c
"
  local expected=c
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo b)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_from_ini_file_case_insensitive() {
  local file="
[foo]
B = c
"
  local expected=c
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo b)
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_get_from_ini_file_case_insensitive_2() {
  local file="
[foo]
b = c
"
  local expected=c
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo B)
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_get_from_ini_file_return_defaults() {
  local file="
[foo]
not = c
"
  local expected=default
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo b "$expected")
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_get_from_ini_file_return_defaults_with_whitespace() {
  local file="
[foo]
not = c
"
  local expected=$'default\nvalue'
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo b "$expected")
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_get_from_ini_file_with_specifier() {
  local file="
[foo name=xyzzy]
b = c
[foo name=not]
b = d
[foo]
b = e
"
  local expected=c
  local actual=
  actual=$(_apply_conf_get_from_ini_file <(echo "$file") foo b "" name=xyzzy)
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_get_names_of_sections() {
  local file="
[foo name=one]
b = c
[foo name=two]
b = d
[not name=nope]
b = e
"
  local expected=$'name=one\nname=two'
  local actual=
  actual=$(_apply_conf_get_sections_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_names_of_sections_with_whitespace() {
  local file="
  [ foo  name   = one ]
 b  =  c
 [ foo  name =   two ]
   b  =  d
"
  local expected=$'name   = one \nname =   two '
  local actual=
  actual=$(_apply_conf_get_sections_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_names_of_sections_case() {
  local file="
[FOO name=one]
b = c
[foo name=two]
b = d
"
  local expected=$'name=one\nname=two'
  local actual=
  actual=$(_apply_conf_get_sections_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_keys_from_ini_file() {
  local file="
[foo]
b = c
[bar]
nope = d
"
  local expected=$'b'
  local actual=
  actual=$(_apply_conf_get_keys_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_keys_from_ini_file_case_insisitive_section() {
  local file="
[FOO]
b = c
"
  local expected=$'b'
  local actual=
  actual=$(_apply_conf_get_keys_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_keys_from_ini_file_case_insisitive_key() {
  local file="
[foo]
B = c
"
  local expected=$'b'
  local actual=
  actual=$(_apply_conf_get_keys_from_ini_file <(echo "$file") foo)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_get_keys_from_ini_file_with_specifier() {
  local file="
[foo bar=baz]
b = c
[foo bar=nope]
nope = d
"
  local expected=$'b'
  local actual=
  actual=$(_apply_conf_get_keys_from_ini_file <(echo "$file") foo bar=baz)
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_parse_ini_file() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo]
b = c
[nope]
nope = d
EOF

  local expected=c
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_parse_ini_file_with_specifier() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo bar=baz]
b = c
[foo bar=nope]
b = d
EOF

  local expected=c
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo bar=baz
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_parse_ini_file_with_specifier_with_whitespace() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo bar = baz]
b = c
[foo bar=nope]
b = d
EOF

  local expected=c
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo "bar = baz"
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_parse_ini_file_with_specifier_lowercasing_keys() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo]
B = c
EOF

  local expected=c
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_parse_ini_file_with_specifier_ignoring_case_of_section_name() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[FOO]
b = c
EOF

  local expected=c
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}


test_apply_conf_can_parse_ini_file_with_many_lines() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo]
b = c1
b = c2
EOF

  local expected=$'c1\nc2'
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_parse_ini_file_with_many_lines() {
  local file=
  file=$(mktemp)
  cat > "$file" <<EOF
[foo]
b = c1
b = c2
EOF

  local expected=$'c1\nc2'
  local actual=
  local output_foo_b=
  _apply_conf_parse_ini_file "$file" output foo
  actual=$output_foo_b
  rm "$file"
  assertEquals "${expected}" "${actual}"
}



test_apply_conf_can_relativize_relative_file_name() {
  local expected=/path/to/full/file-name.txt
  local actual=
  local _apply_conf_config_file=/path/to/config.ini
  actual=$(_apply_conf_relativize full/file-name.txt)
  assertEquals "${expected}" "${actual}"
}

test_apply_conf_can_relativize_leave_absolute_file_name() {
  local expected=/full/file-name.txt
  local actual=
  local _apply_conf_config_file=/path/to/config.ini
  actual=$(_apply_conf_relativize /full/file-name.txt)
  assertEquals "${expected}" "${actual}"
}



## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-bashing.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/common-io.sh"
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece.d/apply-conf.sh"
  log=/tmp/${BASH_SOURCE[0]}.$$.log

  tmp_dir=$(mktemp -d)
  cache_dir=${tmp_dir}/var/lib/escenic
  data_dir=${tmp_dir}/var/lib/escenic
  log_dir=${tmp_dir}/var/log/escenic
  run_dir=${tmp_dir}/var/run/escenic

  
}

## @override shunit2
tearDown() {
  rm -r "${tmp_dir}"
}

main() {
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
