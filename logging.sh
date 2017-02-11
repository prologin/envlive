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

tput_red=$(tput setaf 1)
tput_green=$(tput setaf 2)
tput_orange=$(tput setaf 3)
tput_reset=$(tput sgr0)

_log () {
    local color="${1}"
    shift
    echo "${color}>> ${@}${tput_reset}"
}

log () {
    _log "${tput_green}" "${@}"
}

warn () {
    _log "${tput_orange}" "${@}"
}

fail () {
    _log "${tput_red}" "${@}"
    return 1
}
