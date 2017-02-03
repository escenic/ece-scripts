#! /usr/bin/env bash

# by torstein@escenic.com

print_h2_header "Operating system"

print_h3_header "Kernel"
print_pre_text $(uname -a)

print_h3_header "Distribution"
if [[ "$(which lsb_release)x" != "x" ]]; then
  print_pre_text "$(lsb_release -a 2>/dev/null)"
elif [ -e /etc/redhat-release ]; then
  print_pre_text "$(cat /etc/redhat-release)"
fi

if [ $verbose -eq 1 ]; then
  print_h3_header "Installed packages"
  if [ $(which dpkg)x != "x" ]; then
    print_pre_text "$(dpkg -l 2>/dev/null)"
  elif [ $(which rpm)x != "x" ]; then
    print_pre_text "$(rpm -qa | sort 2>/dev/null)"
  fi
fi

print_h3_header "Timezone"
print_un_ordered_list_start

file=/etc/timezone
if [ -r $file ]; then
  print_list_item "$(cat $file) (from $file)"
fi
file=/etc/sysconfig/clock
if [ -r $file ]; then
  print_list_item "$(cat $file | cut -d'=' -f2 | sed 's/\"//g') (from $file)"
fi

if [ -n "$TZ" ]; then
  print_list_item "$(echo $TZ) (from ${USER}'s environment variable)"
fi
print_un_ordered_list_end


print_h3_header "Last Boot"
print_pre_text "$(who -b | sed -e 's/[a-z]*//g' -e 's/^[ ]*//g')"

# of the h2
print_section_end

