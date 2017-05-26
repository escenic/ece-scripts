#! /usr/bin/env bash

## author: torstein@escenic.com
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

print_doc_header_md() {
  cat << 'EOF'
# Configuration Reference for ece-install

`ece-install` can be configured either in YAML (new) or `.conf`
(old). You pass the file the same way regardless of format:
```
# ece-install -f <file>.yaml
# ece-install -f <file>.conf
```

Both versions are listed below, grouped by topic.
EOF
}

print_doc_header_org() {
  cat <<EOF
Overview of =ece-install='s configuration options. Generated from the
configuration file parser's unit tests @ $(LC_ALL=C date).
EOF
}

print_doc_footer_md() {
  cat <<EOF
---
Reference guide generated: $(LC_ALL=C date)
EOF
}

print_doc_footer_org() {
  :
}

create_doc_md() {
  print_doc_header_md

  cat ece-install-conf-file-reader-test.sh |
    sed -n '/test_can_parse_yaml_conf_.*() {/,/parse_yaml_conf_file_or_source_if_sh_conf/{
  /[ ]*local /d
  /yaml_file=$(mktemp)/d
  /cat > "${yaml_file}" <<EOF/d
  /parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"/d

  s#test_can_parse_yaml_conf_\(.*\)() {#\n\#\# \1#
  s#---#```#
  s#EOF#```#
  s#  unset \(.*\)#- `ece-install.conf` equivalent: `\1`#
  p
}'

  print_doc_footer_md
}

create_doc_org() {
  print_doc_header_org

  cat ece-install-conf-file-reader-test.sh |
    sed -n '/test_can_parse_yaml_conf_.*() {/,/parse_yaml_conf_file_or_source_if_sh_conf/{
  /[ ]*local /d
  /yaml_file=$(mktemp)/d
  /cat > "${yaml_file}" <<EOF/d

  s#test_can_parse_yaml_conf_\(.*\)() {#\n*** \1#
  s#---#\#+begin_src yaml#
  s#EOF#\#+end_src\n=ece-install.conf= equivalent:\n\#+begin_src: text#
  s#  unset \(.*\)#\1=#
  s#[ ]*parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"#\#+end_src#
  p
}'

  print_doc_footer_org
}



# create_doc_md "$@"
create_doc_org "$@"
