#! /usr/bin/env bash

# by per@escenic.com

test_unique_module_listings() {
  wget() {
    cat "$(dirname "$0")/resources/ece-6.4-version-manager-output.html"
  }

  local output
  local expected
  local actual

  output=$(list_versions)
  expected=$(echo "$output" | sort -u | wc -l)
  actual=$(echo "$output" | wc -l)
  assertEquals " Duplicate entries in module list;" "${expected}" "${actual}"

  unset wget
}

test_no_html_markup() {
  wget() {
    cat "$(dirname "$0")/resources/ece-6.4-version-manager-output.html"
  }

  local actual

  actual=$(list_versions | grep -c -i -E "</?(span|pre|li)")
  assertEquals " HTML markup present in output;" "0" "${actual}"

  unset wget
}

test_no_labels() {
  local mock_versions

  mock_versions=$(find "$(dirname "$0")"/resources -name "ece-*-version-manager-output.html" | \
    sed 's/^.*\/ece-\([0-9]\.[0-9]\).*$/\1/')

  for version in ${mock_versions}; do

    wget() {
      cat "$(dirname "$0")/resources/ece-${version}-version-manager-output.html"
    }

    local actual

    actual=$(list_versions | grep -c -E '[^=]+=')
    assertEquals " Non-version number information in output from version ${version};" "0" "${actual}"
  done
    
  unset wget
}

## @override shunit2
setUp() {
  print() {
    echo "$@"
  }

  get_escenic_admin_url() {
    echo "http://localhost:8080/escenic-admin"
  }
  
  set_type_port() {
    :
  }

  # shellcheck disable=SC1090
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece.d/versions.sh"

  export type_pid=42
  export instance=engine1
  export port=8080
}

## @override shunit2
tearDown() {
  unset print
  unset get_escenic_admin_url
  unset set_type_port

  unset type_pid
  unset instance
  unset port
}

main() {
  # shellcheck disable=SC1090
  . "$(dirname "$0")"/shunit2/shunit2
}

main "$@"
