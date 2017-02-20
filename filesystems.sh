# Envlive, a live environment script for contests.
# Copyright (C) 2016  Alexis Cassaigne <alexis.cassaigne@gmail.com>
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
. ./buildlib.sh

##
## PARTITIONNING
##

partition () {
    sfdisk "${1}" < "prololive.${part_mode}"
    dev_boot_id=1
    dev_persistent_id=2
}

##
## FORMATING
##

dos_format () {
    mkfs.ext4 -O ^64bit -F "${dev_boot}" -L proloboot
    mkfs.ext4 -F "${dev_persistent}" -L persistent
}

gpt_format () {
    mkfs.fat  -F32 "${dev_boot}"       -n proloboot
    mkfs.ext4 -F   "${dev_persistent}" -L persistent
}

dos_efi_format () {
    gpt_format
}

gpt_mbr_format () {
    gpt_format
}

format () {
    "${part_mode}_format" "$1"
}

##
## BOOTLOADERS
##

install_gpt_bootloader () {
    bootctl --path="${1}/boot" install --no-variables
    cp -v bootctl/*.conf "${1}/boot/loader/entries/"
    echo "timeout 5" > "${1}/boot/loader/loader.conf"
}

_install_dos_bootloader () {
    mkdir -p "${1}/boot/syslinux"
    cp -vr "${1}"/usr/lib/syslinux/bios/*.c32 "${1}/boot/syslinux/"
    cp -v syslinux.cfg "${1}/boot/syslinux/"
    cp -v boot-bg.png "${1}/boot/syslinux/" || fail "missing boot-bg.png file..."
    dd conv=notrunc if="/usr/lib/syslinux/bios/${2}.bin" of="${dev_loop}" bs=440 count=1
}

install_dos_bootloader () {
    _install_dos_bootloader "$1" "${2:-mbr}"
    extlinux --device "${dev_boot}"  --install "${1}/boot/syslinux/"
}

install_dos_efi_bootloader () {
    for file in "${1}/boot/EFI/"{systemd/systemd-bootx64.efi,Boot/bootx64.efi}; do
	mkdir -p $(dirname "${file}")
	cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "${file}"
    done

    mkdir -p "${1}/boot/loader/entries"
    cp -v bootctl/*.conf "${1}/boot/loader/entries/"

    echo "timeout 5" > "${1}/boot/loader/loader.conf"

    _install_dos_bootloader "$1" mbr

    umount_boot "$1"
    syslinux --directory "syslinux" --install "${dev_boot}"
    mount_boot "$1"
}

install_gpt_mbr_bootloader () {
    install_gpt_bootloader "$1"
    _install_dos_bootloader "$1" gptmbr

    sgdisk "${dev_loop}" --attributes=1:set:2

    umount_boot "$1"
    syslinux --directory "syslinux" --install "${dev_boot}"
    mount_boot "$1"
}

install_bootloader () {
    overlay_mount "$1"
    "install_${part_mode}_bootloader" "$1"
    overlay_umount
}
