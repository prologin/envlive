. ./logging.sh

param_reset () {
    RESET_SQ=true
}

param_verbose () {
    set -x
}

build_user="$SUDO_USER"
param_builduser () {
    build_user="$1"
    __args_used=1
}

param_partmode () {
    part_mode="$1"
    __args_used=1
}

param_ignore () {
    IFS=$':' read -r -a build_ignore <<< "$1"
    __args_used=1
}

param_askpass () {
    while [[ -z "$root_pass" ]]; do
        warn "Please type in the root password :"
	read -s root_pass

	if [[ -z "$root_pass" ]]; then
	    warn "Root password cannot be empty"
	else
	    warn "Type it again :"
	    read -s _root_pass
	    if [[ "$root_pass" == "$_root_pass" ]]; then
		break;
	    else
		warn "Passwords do not match !"
		unset root_pass
	    fi
	fi
    done
    unset _root_pass
}

while [[ "${1:0:2}" == '--' && "${#1}" != 2 ]]; do
    __fname="param_${1:2}"
    shift
    __args_used=0
    "$__fname" "$@"
    shift "${__args_used}"
done

[[ "$build_user" != '' ]] || fail "Could find a default build user. \
Please use either --builduser or sudo"

help_string="Usage: $0 imagename rootpass"

[[ ! -z "$root_pass" ]] || root_pass="${2?$help_string}"
prololive_dir="${1?$help_string}"
prololive_img="${prololive_dir}.img"
