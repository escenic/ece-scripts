# -*- mode: sh; sh-shell: bash; -*-

## Component handling user input parsing.
##
## author: torstein@escenic.com

read_user_input() {
  for el in "$@"; do
    if [[ "${el}" == "-v" || "${el}" == "--verbose" ]]; then
      export debug=1
    elif [[ "${el}" = "-V" || "${el}" == "--version" ]]; then
      echo "Version: ${ece_scripts_version}"
      exit 0
    elif [[ "${el}" == "-f" || "${el}" == "--conf-file" ]]; then
      next_is_conf_file=1
    elif [[ "${el}" == "--only-3rd-party" ]]; then
      export fai_package_only_3rd_party=1
    elif [[ "${el}" == "--only-proprietary" ]]; then
      export fai_package_only_proprietary=1
    elif [[ -n $next_is_conf_file && $next_is_conf_file -eq 1 ]]; then
      conf_file=$el
      case ${conf_file} in
        /*)
        ;;
        *)
          conf_file=$(pwd)/${conf_file}
          ;;
      esac

      next_is_conf_file=0
    fi
  done
}
