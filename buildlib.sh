# Envlive, a live environment script for contests.
# Copyright (C) 2016  Alexis Cassaigne <alexis.cassaigne@gmail.com>
# Copyright (C) 2017  Théophile Bastian <theophile.bastian@prologin.org>
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

mkemptydir() {
    while [[ "$#" > 0 ]]; do
	rm -rf "${1}"
	mkdir "${1}"
	shift
    done
}

runcmd () {
    systemd-nspawn -D "${ROOT}" "$@"
}

isinarr () {
    local needle="$1"
    shift
    local haystack_e
    for haystack_e in "$@"; do
	if [[ "${haystack_e}" == "${needle}" ]]; then
	    return 0
	fi
    done
    return 1
}

section_disabled () {
    isinarr "$1" "${build_ignore[@]}"
}

passwd_encode () {
    echo "${1}" | openssl passwd -1 -stdin
}

allocate_img () {
    rm -f "${1}"
    fallocate -l "${image_size}" "${1}"
    #dd if=/dev/zero of="${1}" bs=1M count="${image_size}" conv=notrunc
}

mount_boot () {
    mkdir -p "${1}/boot"
    mount "${dev_boot}" "${1}/boot"
}

umount_boot () {
    umount "${1}/boot"
}

generate_bootsplash () {
    local splash_name="boot-bg.$(date +%Y).png"
    make "$splash_name"
    ln -sf "$splash_name" "$1"
}

root_configure () {
    rsync -avh --progress root_skel/* "${1}"
    runcmd bash -c '\
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
locale-gen
systemctl enable sddm
systemctl enable NetworkManager.service
/sbin/ldconfig -X'
}

install_systemd_boot () {
    mount
    if [[ "$part_mode" == 'gpt' ]]; then
	bootctl --path="${1}" install --no-variables
    else

	mkdir -p "${1}/EFI/systemd/"
	cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "${1}/EFI/systemd/"
	mkdir -p "${1}/loader/entries"
	echo "timeout 3" > "${1}/loader/loader.conf"
    fi
    cp arch.conf "${1}/loader/entries/"
}

install_syslinux () {
    mount "${dev_boot}" "${1}"
    mkdir -p "${1}/syslinux"
    cp -vr /usr/lib/syslinux/bios/*.c32 "${1}/syslinux/"
    cp -v syslinux.cfg "${1}/syslinux/"
    cp -v boot-bg.png "${1}/syslinux/" || (
	echo "missing boot-bg.png file..."
	exit 2
    )
    umount "${1}"

    dd conv=notrunc if='/usr/lib/syslinux/bios/mbr.bin' of="${prololive_img}" bs=440 count=1
    syslinux --install "${dev_boot}" --directory "syslinux"
}

install_docs () {
    mkdir -p "${1}/home/prologin/.local/share/Zeal/Zeal/"
	[ -d "docs" ] && \
		cp -r docs "${1}/home/prologin/.local/share/Zeal/Zeal/docsets"
    runcmd -u root chown -R prologin:prologin /home/prologin/.local
}


mount_hook () {
    "${1}" "Recursively umounting the root..."
    umount -R "${prololive_dir}" 2>/dev/null || :
}

probe_hook () {
    "${1}" "Detaching the loop device..."
    losetup -d "${dev_loop}" &>/dev/null || :
}

probe_img () {
    losetup --partscan --find --show "$1"
}

__finish_hooks=( )

finish_hook_add () {
    __finish_hooks+=( "${@}" )
}

finish_hooks () {
    local exit_code="$?"
    local log_cmd='log'
    if [[ "${exit_code}" != 0 ]]; then
	warn "The script failed !"
	log_cmd='warn'
    fi
    "${log_cmd}" "Running exit hooks..."

    for hook in "${__finish_hooks[@]}"; do
	"${hook}" "${log_cmd}"
    done
}
