# -*- mode: sh; sh-shell: bash; -*-

## Run configured pre and post installation hooks and give these the
## ece-install configuration.

## author: torstein@escenic.com

_is_hook_ok_to_run() {
  local hook=$1

  [[ -e "${hook}" && -x "${hook}" ]]
}

_hooks_run_hooks() {
  local hook_type=$1
  local hooks=$2

  for hook in ${hooks}; do
    if _is_hook_ok_to_run "${hook}"; then
      for var in $(compgen -A variable | grep ^fai_); do
        export "${var}"
      done
      "${hook}"
    else
      print_and_log \
        "Skipping ${hook_type} hook ${hook}, " \
        "it must exist and be executable"
    fi
  done
}

hooks_run_preinst() {
  _hooks_run_hooks preinst "${fai_hooks_preinst}"
}

hooks_run_postinst() {
  _hooks_run_hooks postinst "${fai_hooks_preinst}"
}

