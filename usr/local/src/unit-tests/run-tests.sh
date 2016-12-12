#! /usr/bin/env bash

# by torstein@gmail.com
set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

id="[$(basename "$0")]"

print() {
  echo "${id} $*"
}

run_tests() {
  for el in $(dirname "$0")/*test.sh; do
    print "Running ${el} ..."
    local shell=bash
    (
      exec ${shell} "${el}" 2>&1
    )
  done
}

ensure_shunit_is_available() {
  (
    cd "$(dirname "$0")"

    if [ ! -d shunit2 ]; then
      print "Downloading shunit ..."
      git clone https://github.com/kward/shunit2.git
    fi
  )
}

main() {
  ensure_shunit_is_available
  run_tests
}

main "$@"
