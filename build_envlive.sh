#!/bin/bash
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

set -e

. ./config.sh
. ./buildlib.sh
. ./overlaylib.sh
. ./logging.sh
. ./filesystems.sh
. ./params.sh

[ $UID -ne 0 ] && fail "This script must run as root !"

overlay_mount_hook_add  mount_boot
overlay_umount_hook_add umount_boot
trap finish_hooks EXIT

if [[ "${RESET_SQ}" == 'true' ]]; then
    warn "This run will reset squashfses."
    warn "Sleeping for 5 seconds..."
    sleep 5
fi

##
## Image allocation / partitionning
##

log "Allocating ${prololive_img}..."
allocate_img "${prololive_img}"

log "Partitionning the disk image"
partition "${prololive_img}"

log "Generate device mappings for the disk image..."
dev_loop=$(probe_img "${prololive_img}")
finish_hook_add probe_hook

dev_boot="${dev_loop}p${dev_boot_id}"
dev_persistent="${dev_loop}p${dev_persistent_id}"

log "Format disk image partitions..."
format "${prololive_img}"
finish_hook_add mount_hook

ROOT="${prololive_dir}"

roots=( "${prololive_dir}.full" \
	"${prololive_dir}.big" \
	"${prololive_dir}.light" )

mkdir -p "${roots[@]}" "${ROOT}"

if [[ "${RESET_SQ}" == 'true' ]]; then

    ##
    ## Build overlays
    ##

    log "Create mountpoints and directories..."
    mkemptydir "${prololive_dir}" $(for root in ${roots[@]}; do section_disabled ${root##*.} || echo "$root"; done)

    log "Install core system packages on the lower layer"
    overlay_stack "${prololive_dir}.light" "${prololive_dir}"
    section_disabled light || pacstrap -C pacman.conf -c "${ROOT}" "${packages_base[@]}"

    section_disabled initcpio || (
	log "Copy hook files..."
	cp -v prolomount.build   "${ROOT}/usr/lib/initcpio/install/prolomount"
	cp -v prolomount.runtime "${ROOT}/usr/lib/initcpio/hooks/prolomount"

	log "Generate the initcpio ramdisk..."
	cp -v mkinitcpio.conf "${ROOT}/etc/mkinitcpio.conf"
	runcmd mkinitcpio -p linux
    )

    log "Install interpreters (GHC apart) and graphical packages on the intermediate layer"
    overlay_stack "${prololive_dir}.big"
    section_disabled big || pacstrap -C pacman.conf -c "${ROOT}/" "${packages_intermediate[@]}"

    log "Install remaining and big packages on the top layer..."
    overlay_stack "${prololive_dir}.full"
    section_disabled full || (
	pacstrap -C pacman.conf -c "${ROOT}/" "${packages_big[@]}"

	##
	## Configure system environment
	##

	log "System configuration..."
	root_configure "${ROOT}"

	# Configure passwords for prologin and root users
	log "Configuring users and passwords..."
	runcmd usermod root \
	       -p "$(passwd_encode "${root_pass}")" \
	       -s /bin/zsh
	runcmd useradd prologin -G games -m \
	       -p "$(passwd_encode prologin)"\
	       -s /bin/zsh
    )

    section_disabled aur || (
	log "Building AUR packages..."
	sudo -u "${build_user}" mkdir -p "${aur_cache}"
	runcmd pacman -Sy
	for package in "${packages_aur[@]}"; do
	    sudo -u "${build_user}" PKGDEST="$(realpath "${aur_cache}")" \
		 pacaur --noconfirm --noedit -m "$package"
	done

	log "Installing AUR packages..."
	rm -rf "${ROOT}/root/aurpkgs"
	cp -r "${aur_cache}" "${ROOT}/root/aurpkgs"
	runcmd sh -c 'pacman -U --noconfirm /root/aurpkgs/*'
	rm -r "${ROOT}/root/aurpkgs"
    )

    # Create dirs who will be ramfs-mounted
    runcmd -u prologin mkdir /home/prologin/.cache /home/prologin/ramfs

    log "Copy docs to prologin's home..."
    install_docs "${ROOT}"

    mkemptydir boot_backup
    cp -vr "${ROOT}"/boot/* boot_backup

    overlay_umount
else
    overlay_list_set "${roots[@]}"
fi

if [[ "${RESET_SQ}" != 'true' && -d boot_backup ]]; then
    mount "${dev_boot}" "${ROOT}"
    log "Copy the cached kernel and initramfs to /boot"
    cp -vr boot_backup/* "${ROOT}"
    umount "${ROOT}"
fi

log "Installing bootloader..."
install_bootloader "${ROOT}"

mount "${dev_boot}" "${ROOT}"

if [[ "${RESET_SQ}" == 'true' ]]; then
    for mountpoint in "${roots[@]}" ; do
        rm -rf "${mountpoint}.squashfs"
    done
fi

log "Create squash filesystems..."
for mountpoint in "${roots[@]}" ; do
    if [ ! -f "${mountpoint}.squashfs" ]; then
	mksquashfs "${mountpoint}" "${mountpoint}.squashfs" \
		   -comp xz -Xdict-size 100% -b 1048576 \
		   -e "${mountpoint}/{proc,boot,tmp,sys,dev}"
    fi
done

log "Copy squash filesystems..."
for mountpoint in "${roots[@]}"; do
    cp -v "${mountpoint}.squashfs" "${ROOT}/prololive.${mountpoint##*.}.squashfs"
done

sync
umount "${ROOT}"

log "Done."
