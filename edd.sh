#!/bin/bash
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

help_string="Usage: $0 prololive.img /dev/device"
input_image="${1?$help_string}"
output_device="${2?$help_string}"

function fail() {
    echo -e "$(tput setaf 1)${@}\n${help_string}$(tput sgr0)"
    exit 1
}

if [[ ! -b "${output_device}" ]] ; then
    fail "the second argument must be a block device (like /dev/sdc)"
fi

if findmnt -- "${output_device}" >/dev/null; then
    fail "the target device is mounted. you may be trying to wipe your disk, be careful"
fi

if egrep '^.+[0-9]+$' <<< "${output_device}" 1>/dev/null; then
    fail "output file must not be a partition (like /dev/sdb1) but a whole block device (/dev/sdb)"
fi

/usr/bin/dd status=progress \
            bs=10M \
            oflag=direct \
            conv=fsync \
            if="${input_image}" \
            of="${output_device}"
