#! /usr/bin/env bash

# by torstein@escenic.com

## $1 is the instance name
function create_ece_overview() {
  local type=$(get_instance_type $1)

  if [ $(whoami) == "root" ]; then
    if [ -n "$ece_user" ]; then
      local command="ece -q -i $1 info -t $type"
      local data="$(su - $ece_user -c " $command ")"$'\n'

      command="ece -q -i $1 status"
      if [ "UP" == "$(su - $ece_user -c "$command" | cut -d' ' -f1)" ]; then
        command="ece -q -i $1 -t $type versions"
        data="$data $(su - $ece_user -c" $command " | cut -d'*' -f2-)"
      fi
    fi
  else
    local data="$(ece -q -i $1 info)"$'\n'

    if [ "UP" == "$(ece -q -i $1 status -t $type | cut -d' ' -f1)" ]; then
      data="$data $(ece -q -i $1 versions -t $type | cut -d'*' -f2-)"
    fi
  fi


  echo "$data" | while read line; do
    if [[ $line == "|->"* ]]; then
      print_list_item $(wrap_in_anchor_if_applicable ${line:3})
    elif [ $(echo $line | cut -d':' -f2- | wc -c) -gt 1 ]; then
      print_list_item $(wrap_in_anchor_if_applicable $line)
    elif [ -n "$line" ]; then
      print_un_ordered_list_end
      print_h4_header $(echo $line | cut -d: -f1)
      print_un_ordered_list_start
    fi
  done

  print_un_ordered_list_end

  if [ ${temporaries-1} -eq 1 ]; then
    list_error_overview_for_instance $1
    list_import_overview_for_instance $1
  fi
}

## $1 :: the instance name
function list_error_overview_for_instance() {
  local file=/var/log/escenic/${1}-messages
  if [ ! -r $file ]; then
    return
  fi

  print_h4_header "Overview of ${1}'s errors"
  # listing the top 50 errors with indiviual count
  local errors="$(grep ERROR ${file} | cut -d' ' -f6- | sort | uniq -c | sort -n -r | sed 's/^[ ]*//g' | sed 's/<[^>]*>//g' | head -n 50)"
  if [ $(echo "$errors" | wc -c) -lt 5 ]; then
      print_pre_text "There are no errors in today's log ($file)"
  else
      print_pre_text "$errors"
  fi
}

function get_overview_of_all_instances() {
  local instance_list=$(get_instance_enabled_list)
  if [ -z "$instance_list" ]; then
    return
  fi

  print_h2_header "Overview of all the ECE instances on $HOSTNAME"
  for el in $(get_instance_list); do
    print_h3_header "Overview of instance $el"
    print_un_ordered_list_start
    create_ece_overview $el
  done

  print_section_end
}

function check_picture_file() {
  local dir=$(dirname "$1")
  local file_name=$(basename "$1")

  if [ ! -e $1 ]; then
    print_p_text "Picture file doesn't exist: $1"
    return
  fi

  local alternative=$(find $dir -maxdepth 1 | grep -i "$file_name")

  # first check if the image is size=0
  if [ $(find $dir -name $file_name -maxdepth 1 -type f -size 0 | wc -l) -gt 0 ]; then
    print_p_text "The file $1 is empty (size = 0 bytes)"
    return
  fi

  if [[ -n "$alternative" && $(echo $alternative | wc -l) -gt 0 ]]; then
    if [[ "$1" == "$alternative" ]]; then
      print_p_text "The XML refered to ${1}" \
        "which exists. This means either that the file wasn't there before when" \
        "the import failed or that the file itself is unusable."
      return
    fi

    print_p_text "The file $1" \
      "was missing from your import data set It was referred to from one of" \
      "your XML files, perhaps you meant this one?" \
      $alternative \
      "Suggested command to fix this:"
    print_pre_text "mv \"$alternative\" \"$1\""
  fi
}

## $1 is thefile
function list_sax_errors() {
  local file=/var/log/escenic/${1}-messages
  local result="$(grep ^'Caused by: org.xml.sax.SAXParseException:' $file | sort | uniq)"

  if [ -z $result ]; then
    return
  fi

  print_p_text "There are illegal elements, attributes" \
    "and/or contents in the XML:"
  print_pre_text "$result"
}

function list_import_overview_for_instance() {
  if [ ${generate_import_job_overview-0} -eq 0 ]; then
    return
  fi

  local file=/var/log/escenic/${1}-messages

  if [ ! -e $file ]; then
    return
  fi

  print_h4_header "Overview of ${1}'s import jobs"

  grep "Invalid image file" $file | \
    grep ^java.io.IOException | \
    cut -d' ' -f5 | \
    sed 's/\.$//g' | \
    sort | \
    uniq | \
    while read picture_path; do
    check_picture_file "$picture_path"
  done

  list_sax_errors "$1"
}

get_overview_of_all_instances
