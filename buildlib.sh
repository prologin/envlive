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

root_configure () {
    rsync -avh --progress root_skel/* "${1}"
    runcmd bash -c '\
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
locale-gen
systemctl enable sddm
systemctl enable NetworkManager.service
/sbin/ldconfig -X
archlinux-java set java-8-openjdk'

    echo 'alias ocaml="rlwrap ocaml"'   >> "${1}/etc/skel/.zshrc"
    echo 'source /etc/profile.d/jre.sh' >> "${1}/etc/skel/.zshrc"
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
