#!/bin/bash

set -e

. ./config.sh
. ./buildlib.sh
. ./overlaylib.sh
. ./logging.sh
. ./filesystems.sh

param_reset () {
    RESET_SQ=true
}

param_verbose () {
    set -x
}


param_partmode () {
    part_mode="$1"
    __args_used=1
}

while [[ "${1:0:2}" == '--' && "${#1}" != 2 ]]; do
    __fname="param_${1:2}"
    shift
    __args_used=0
    "$__fname" "$@"
    shift "${__args_used}"
done

help_string="Usage: $0 imagename rootpass"

root_pass="${2?$help_string}"
prololive_dir="${1?$help_string}"
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
partition "${prololive_img}"

log "Generate device mappings for the disk image..."
dev_loop=$(losetup --partscan --find --show "${prololive_img}")

dev_boot="${dev_loop}p${dev_boot_id}"
dev_persistent="${dev_loop}p${dev_persistent_id}"


finish () {
    local exit_code="$?"
    local log_cmd='log'
    if [[ "${exit_code}" != 0 ]]; then
	warn "The script failed !"
	log_cmd='warn'
    fi
    "${log_cmd}" "Unmounting eventually mounted filesystems..."
    umount -R "${prololive_dir}" 2>/dev/null || :
    losetup -d "${dev_loop}" &>/dev/null || :
}
trap finish EXIT


log "Format disk image partitions..."
format "${prololive_img}"

ROOT="${prololive_dir}"

roots=( "${prololive_dir}.full" \
	"${prololive_dir}.big" \
	"${prololive_dir}.light" )

if [[ "${RESET_SQ}" == 'true' ]]; then

    ##
    ## Build overlays
    ##

    log "Create mountpoints and directories..."
    mkemptydir "${prololive_dir}" "${roots[@]}"

    log "Install core system packages on the lower layer"
    overlay_stack "${prololive_dir}.light" "${prololive_dir}"
    pacstrap -C pacman.conf -c "${ROOT}" "${packages_base[@]}"

    log "Copy hook files..."
    cp -v prolomount.build   "${ROOT}/usr/lib/initcpio/install/prolomount"
    cp -v prolomount.runtime "${ROOT}/usr/lib/initcpio/hooks/prolomount"


    log "Generate the initcpio ramdisk..."
    cp -v mkinitcpio.conf "${ROOT}/etc/mkinitcpio.conf"
    runcmd mkinitcpio -p linux

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
    runcmd usermod root \
	   -p "$(passwd_encode "${root_pass}")" \
	   -s /bin/zsh
    runcmd useradd prologin -G games -m \
	   -p "$(passwd_encode prologin)"\
	   -s /bin/zsh

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

if [[ "${RESET_SQ}" != 'true' ]]; then
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
    cp -v "${mountpoint}.squashfs" "${ROOT}/${mountpoint}.squashfs"
done

sync
umount "${ROOT}"

log "Done."
