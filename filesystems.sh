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

format () {
    "${part_mode}_format" "$1"
}

##
## BOOTLOADERS
##

install_gpt_bootloader () {
    runcmd bootctl --path="${1}/boot" install --no-variables
}

install_dos_bootloader () {
    mkdir -p "${1}/boot/syslinux"
    cp -vr "${1}"/usr/lib/syslinux/bios/*.c32 "${1}/boot/syslinux/"
    cp -v syslinux.cfg "${1}/boot/syslinux/"
    cp -v boot-bg.png "${1}/boot/syslinux/" || (
	echo "missing boot-bg.png file..."
	exit 2
    )
    dd conv=notrunc if='/usr/lib/syslinux/bios/mbr.bin' of="${prololive_img}" bs=440 count=1
    #dd if='/usr/lib/syslinux/bios/mbr.bin' of="${dev_loop}" bs=440 count=1
    extlinux --device "${dev_boot}"  --install "${1}/boot/syslinux/"
}

install_bootloader () {
    overlay_mount "$1"
    "install_${part_mode}_bootloader" "$1"
    overlay_umount
}
