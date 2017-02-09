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

format () {
    "${part_mode}_format" "$1"
}

##
## BOOTLOADERS
##

install_gpt_bootloader () {
    overlay_mount "$1"
    bootctl --path="${1}/boot" install --no-variables
    cp arch.conf "${1}/boot/loader/entries/"
    overlay_umount
}

_install_dos_bootloader () {
    mkdir -p "${1}/boot/syslinux"
    cp -vr "${1}"/usr/lib/syslinux/bios/*.c32 "${1}/boot/syslinux/"
    cp -v syslinux.cfg "${1}/boot/syslinux/"
    cp -v boot-bg.png "${1}/boot/syslinux/" || fail "missing boot-bg.png file..."
    dd if='/usr/lib/syslinux/bios/mbr.bin' of="${dev_loop}" bs=440 count=1
}

install_dos_bootloader () {
    overlay_mount "$1"
    _install_dos_bootloader "$1"
    extlinux --device "${dev_boot}"  --install "${1}/boot/syslinux/"
    overlay_umount
}

install_dos_efi_bootloader () {
    overlay_mount "$1"
    for file in "${1}/boot/EFI/"{systemd/systemd-bootx64.efi,Boot/bootx64.efi}; do
	mkdir -p $(dirname "${file}")
	cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "${file}"
    done

    mkdir -p "${1}/boot/loader/entries"
    cp arch.conf "${1}/boot/loader/entries/"

    echo "timeout 3" > "${1}/boot/loader/loader.conf"

    _install_dos_bootloader "$1"
    overlay_umount

    syslinux --directory "syslinux" --install "${dev_boot}"
}

install_bootloader () {
    "install_${part_mode}_bootloader" "$1"
}
