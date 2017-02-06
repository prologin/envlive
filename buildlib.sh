mkemptydir() {
    while [[ "$#" > 0 ]]; do
	rm -rf "${1}"
	mkdir "${1}"
	shift
    done
}

allocate_img () {
    rm -f "${1}"
    fallocate -l "${image_size}" "${1}"
    dd if=/dev/zero of="${1}" bs=1M count=1 conv=notrunc
}

mount_boot () {
    mkdir -p "${1}/boot"
    mount "${dev_boot}" "${1}/boot"
}

umount_boot () {
    umount "${1}/boot"
}

root_configure () {
    rsync -avh --progress root_skel "${1}"
    systemd-nspawn -D "${1}" ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    systemd-nspawn -D "${1}" locale-gen
    systemd-nspawn -D "${1}" systemctl enable sddm
    systemd-nspawn -D "${1}" systemctl enable NetworkManager.service
    systemd-nspawn -D "${1}" /sbin/ldconfig -X

    echo 'alias ocaml="rlwrap ocaml"'   >> "${1}/etc/skel/.zshrc"
    echo 'source /etc/profile.d/jre.sh' >> "${1}/etc/skel/.zshrc"
}

install_bootloader () {
    bootctl --path="${1}" install --no-variables
    cp arch.conf "${1}/loader/entries/"
}

install_docs () {
    mkdir -p "${ROOT}/home/prologin/.local/share/Zeal/Zeal/docsets"
    cp -r docs/* "${ROOT}/home/prologin/.local/share/Zeal/Zeal/docsets"
    systemd-nspawn -D "${ROOT}" -u root chown -R prologin:prologin /home/prologin/.local
}
