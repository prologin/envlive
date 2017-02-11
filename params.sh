# Envlive, a live environment script for contests.
# Copyright (C) 2017  Victor Collod <victor.collod@prologin.org>
# Copyright (C) 2017  Association Prologin <info@prologin.org>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
