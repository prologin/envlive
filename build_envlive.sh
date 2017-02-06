#!/bin/bash

set -e

. ./config.sh
. ./buildlib.sh
. ./overlaylib.sh
. ./logging.sh

help_string="Usage: $0 imagename rootpass"

root_pass=${2?$help_string}
prololive_dir=${1?$help_string}
prololive_img="${prololive_dir}.img"

[ $UID -ne 0 ] && fail "This script must run as root !"

overlay_mount_hook_add  mount_boot
overlay_umount_hook_add umount_boot

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
sfdisk "${prololive_img}" < prololive.dos

log "Generate device mappings for the disk image..."
dev_loop=$(kpartx -asv "${prololive_img}" | grep -o "loop[0-9]" | tail -n1)


finish () {
    local exit_code="$?"
    local log_cmd='log'
    if [[ "${exit_code}" != 0 ]]; then
	warn "The script failed !"
	log_cmd='warn'
    fi
    "${log_cmd}" "Unmounting eventually mounted filesystems..."
    umount -R "${prololive_dir}" 2>/dev/null || :
    kpartx -sd "${prololive_img}" &>/dev/null || :
}
trap finish EXIT

dev_boot="/dev/mapper/${dev_loop}p1"
dev_persistent="/dev/mapper/${dev_loop}p2"

log "Format disk image partitions..."
mkfs.fat  -F32 "${dev_boot}"       -n proloboot
mkfs.ext4 -F   "${dev_persistent}" -L persistent


##
## Build overlays
##

roots=( "${prololive_dir}.light" \
	    "${prololive_dir}.big" \
	    "${prololive_dir}.full" )


log "Create mountpoints and directories..."
mkemptydir "${roots[@]}"

ROOT="${prololive_dir}"

log "Install core system packages on the lower layer"
overlay_stack "${prololive_dir}.light" "${prololive_dir}"
pacstrap -C pacman.conf -c "${ROOT}" "${packages_base[@]}"

log "Copy hook files..."
cp -v prolomount.build   "${ROOT}/usr/lib/initcpio/install/prolomount"
cp -v prolomount.runtime "${ROOT}/usr/lib/initcpio/hooks/prolomount"


log "Generate the initcpio ramdisk..."
cp -v mkinitcpio.conf "${ROOT}/etc/mkinitcpio.conf"
systemd-nspawn -D "${ROOT}" mkinitcpio -p linux

log "Install interpreters (GHC apart) and graphical packages on the intermediate layer"
overlay_stack "${prololive_dir}.big"
pacstrap -C pacman.conf -c "${ROOT}/" "${packages_intermediate[@]}"

log "Install remaining and big packages on the top layer..."
overlay_stack "${prololive_dir}.full"
pacstrap -C pacman.conf -c "${ROOT}/" "${packages_big[@]}"


##
## Configure system environment
##

log "System configuration..."
root_configure "${ROOT}"

# Configure passwords for prologin and root users
log "Configuring users and passwords..."
systemd-nspawn -D "${ROOT}" usermod root -p "$(echo "${root_pass}" | openssl passwd -1 -stdin)" -s /bin/zsh
systemd-nspawn -D "${ROOT}" useradd prologin -G games -m -p "$(echo "prologin" | openssl passwd -1 -stdin)" -s /bin/zsh

# Create dirs who will be ramfs-mounted
systemd-nspawn -D "${ROOT}" -u prologin mkdir /home/prologin/.cache /home/prologin/ramfs

log "Copy docs to prologin's home..."
install_docs "${ROOT}"

# Configure boot system
log "Installing systemd-boot..."
install_bootloader "${ROOT}/boot"

overlay_umount

BOOT="${prololive_dir}"

mount "${dev_boot}" "${BOOT}"

if [[ "${RESET_SQ}" == 'true' ]]; then
    for mountpoint in "${roots[@]}" ; do
        rm -rf "${mountpoint}.squashfs"
    done
fi

# Creating squash filesystems
echo "Create squash filesystems..."
for mountpoint in "${roots[@]}" ; do
    if [ ! -f "${mountpoint}.squashfs" ]; then
	mksquashfs "${mountpoint}" "${mountpoint}.squashfs" \
		   -comp xz -Xdict-size 100% -b 1048576 \
		   -e "${mountpoint}/{proc,boot,tmp,sys,dev}"
    fi
done

echo "Copy squash filesystems..."
for mountpoint in "${roots[@]}"; do
    cp "${mountpoint}.squashfs" "${BOOT}/${mountpoint}.squashfs"
done

log "Done."
