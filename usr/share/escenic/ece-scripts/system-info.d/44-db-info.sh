#! /usr/bin/env bash

# by torstein@escenic.com

if [ "$(which mysqld 2>/dev/null)x" != "x" ]; then
  print_h2_header "DB information"
  print_pre_text "$(mysqld -V)"
  print_section_end
fi
