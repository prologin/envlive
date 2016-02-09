#!/bin/sh

set -e

# Load the config
. ./config.sh

mkemptydir() {
    rm -rf "${1}"
    mkdir "${1}"
}

# Clean previous builds
echo "Unmount eventually mounted filesystems..."
for fs in "${PROLOLIVE_DIR}.bind.light/boot" "${PROLOLIVE_DIR}.bind.light" overlay-intermediate overlay-intermediate/boot "${PROLOLIVE_DIR}/boot" "${PROLOLIVE_DIR}" ; do
    umount -R "${fs}" 2>/dev/null || :
done

kpartx -sd "${PROLOLIVE_IMG}" &>/dev/null || :
echo "Done."


echo "Allocate prololive.img..."
rm -f "${PROLOLIVE_IMG}"
fallocate -l 3824M "${PROLOLIVE_IMG}"
dd if=/dev/zero of="${PROLOLIVE_IMG}" bs=1M count=1 conv=notrunc
echo "Done."

# Partition the image disk file
echo "Partition the disk image"
sfdisk "${PROLOLIVE_IMG}" < prololive.dos

# Create loop devices for the disk image file
echo "Generate device mappings for the disk image..."
LOOP=$(kpartx -asv "${PROLOLIVE_IMG}" | grep -o "loop[0-9]" | tail -n1)
echo "Done."

echo "Format disk image partitions..."
mkfs.ext4 -F "/dev/mapper/${LOOP}p1" -L proloboot
mkfs.ext4 -F "/dev/mapper/${LOOP}p2" -L persistent
echo "Done."


echo "Create mountpoints and directories..."
mkemptydir "${PROLOLIVE_DIR}/"           # Mount the full overlayfs r/w here
mkemptydir "${PROLOLIVE_DIR}.light"      # Install only the base system here
mkemptydir "${PROLOLIVE_DIR}.big"        # Install interpreters (ghc apart) here, as well as WE/DM
mkemptydir "${PROLOLIVE_DIR}.full"       # Install the biggest packages here
mkemptydir "${PROLOLIVE_DIR}.bind.light" # Bind ${PROLOLIVE_DIR}.light/system here
mkemptydir overlay-intermediate          # Overlay-mount ${PROLOLIVE_DIR}.light and ${PROLOLIVE_DIR}.big

for mountpoint in "${PROLOLIVE_DIR}.light" "${PROLOLIVE_DIR}.big" "${PROLOLIVE_DIR}.full" ; do
    mkdir "${mountpoint}/work" "${mountpoint}/system"
done


echo "Install packages..."
echo "Install core system packages on the lower layer"
ROOT="${PROLOLIVE_DIR}.bind.light"
mount -o bind "${PROLOLIVE_DIR}.light/system" "${ROOT}"
mkdir "${ROOT}/boot"
mount "/dev/mapper/${LOOP}p1" "${ROOT}/boot"
pacstrap -C pacman.conf -c "${ROOT}" base base-devel syslinux

# Copy the hook needed to mount squash filesystems on boot
echo "Copy hook files..."
cp -v prolomount.build "${ROOT}/usr/lib/initcpio/install/prolomount"
cp -v prolomount.runtime "${ROOT}/usr/lib/initcpio/hooks/prolomount"
echo "Done."


# Copy config and generating initcpio
echo "Generate the initcpio ramdisk..."
cp -v mkinitcpio.conf "${ROOT}/etc/mkinitcpio.conf"
systemd-nspawn -D "${ROOT}" mkinitcpio -p linux

umount "${ROOT}/boot"
umount "${ROOT}"

echo "Install interpreters (GHC apart) and graphical packages on the intermediate layer"
ROOT=overlay-intermediate
mount -t overlay overlay -o "lowerdir=${PROLOLIVE_DIR}.light/system,upperdir=${PROLOLIVE_DIR}.big/system,workdir=${PROLOLIVE_DIR}.big/work" "${ROOT}"
mkdir -p "${ROOT}/boot"
mount "/dev/mapper/${LOOP}p1" "${ROOT}/boot"
pacstrap -C pacman.conf -c "${ROOT}/" boost ed firefox firefox-i18n-fr fpc \
	 gambit-c gcc-ada gdb git grml-zsh-config htop jdk7-openjdk \
	 lxqt-common lxqt-config lxqt-panel lxqt-policykit lxqt-qtplugin \
	 lxqt-runner lxqt-session openbox oxygen-icons pcmanfm-qt luajit mono \
	 mono-basic mono-debugger nodejs ntp ntfs-3g ocaml openssh php python \
	 python2 qtcreator rlwrap rxvt-unicode screen sddm tmux valgrind wget \
	 xorg xorg-apps zsh vim emacs networkmanager network-manager-applet \
	 xterm


umount "${ROOT}/boot"
umount "${ROOT}"

echo "Install remaining and big packages on the top layer (${PROLOLIVE_DIR})"
ROOT="${PROLOLIVE_DIR}"
mount -t overlay overlay -o "lowerdir=${PROLOLIVE_DIR}.big/system:${PROLOLIVE_DIR}.light/system,upperdir=${PROLOLIVE_DIR}.full/system,workdir=${PROLOLIVE_DIR}.full/work" "${ROOT}"
mkdir -p "${ROOT}/boot"
mount "/dev/mapper/${LOOP}p1" "${ROOT}/boot"
pacstrap -C pacman.conf -c "${ROOT}/" codeblocks eclipse eric esotope-bfc-git \
	 eric-i18n-fr fsharp geany ghc leafpad monodevelop \
	 monodevelop-debugger-gdb netbeans notepadqq-bin openjdk7-doc \
	 pycharm-community reptyr rsync samba scite sublime-text

# Configure system environment
echo "System configuration..."
echo "prololive" > "${ROOT}/etc/hostname"
systemd-nspawn -D "${ROOT}" ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo 'fr_FR.UTF-8 UTF-8' >  "${ROOT}/etc/locale.gen"
echo 'en_US.UTF-8 UTF-8' >> "${ROOT}/etc/locale.gen"
echo "LANG=fr_FR.UTF-8"  >  "${ROOT}/etc/locale.conf"
echo "KEYMAP=fr-pc"      >  "${ROOT}/etc/vconsole.conf"
systemd-nspawn -D "${ROOT}" locale-gen
cp -v sddm.conf "${ROOT}/etc/"
systemd-nspawn -D "${ROOT}" systemctl enable sddm
cp -v 00-keyboard.conf "${ROOT}/etc/X11/xorg.conf.d/"
systemd-nspawn -D "${ROOT}" systemctl enable NetworkManager.service
systemd-nspawn -D "${ROOT}" /sbin/ldconfig -X


# Copy user configuration files
cp -v .Xresources "${ROOT}/etc/skel/"
systemd-nspawn -D "${ROOT}" mkdir -p /etc/skel/.config/Eric6
cp -v eric6.ini "${ROOT}/etc/skel/.config/"
cp -vr prologin/. "${ROOT}/etc/skel/"
echo 'alias ocaml="rlwrap ocaml"' >> /etc/skel/.zshrc
echo 'source /etc/profile.d/jre.sh' >> /etc/skel/.zshrc


cat > "${ROOT}/etc/systemd/journald.conf" <<EOF
[Journal]
Storage=volatile
EOF

# Configure passwords for prologin and root users
echo "Configuring users and passwords..."
systemd-nspawn -D "${ROOT}" usermod root -p "$(echo "${CANONIQUE}" | openssl passwd -1 -stdin)" -s /bin/zsh
systemd-nspawn -D "${ROOT}" useradd prologin -G games -m -p "$(echo "prologin" | openssl passwd -1 -stdin)" -s /bin/zsh
echo "Done."


# Copy the pacman config
cp -v pacman.conf "${ROOT}/etc/"


# Configure fstab
cat > "${ROOT}/etc/fstab" <<EOF
LABEL=proloboot /boot                     ext4  defaults 0 0
tmpfs           /home/prologin/.cache     tmpfs defaults 0 0
tmpfs           /home/prologin/ramfs      tmpfs defaults 0 0
EOF


# Create dirs who will be ramfs-mounted
systemd-nspawn -D "${ROOT}" -u prologin mkdir /home/prologin/.cache /home/prologin/ramfs


# Configure boot system
echo "Installing syslinux..."
dd if="${ROOT}/usr/lib/syslinux/bios/mbr.bin" of="/dev/${LOOP}" bs=440 count=1
mkdir -p "${ROOT}/boot/syslinux"
cp -vr "${ROOT}"/usr/lib/syslinux/bios/*.c32 "${ROOT}/boot/syslinux/"
extlinux --device "/dev/mapper/${LOOP}p1" --install "${ROOT}/boot/syslinux"

#cp -v logo.png "${ROOT}/boot/syslinux/" || (echo "missing logo.png file..." && exit 42)
cp -v boot-bg.png "${ROOT}/boot/syslinux/" || (echo "missing boot-bg.png file..." && exit 42)
cp -v syslinux.cfg "${ROOT}/boot/syslinux/"
echo "Done."

umount "${ROOT}/boot"
umount "${ROOT}"

BOOT="${PROLOLIVE_DIR}"

mount "/dev/mapper/${LOOP}p1" "${BOOT}"
cp -v documentation.squashfs "${BOOT}/"


# Creating squash filesystems
echo "Create squash filesystems..."
for mountpoint in "${PROLOLIVE_DIR}.light" "${PROLOLIVE_DIR}.big" "${PROLOLIVE_DIR}.full" ; do
    mksquashfs "${mountpoint}/system" "${BOOT}/${mountpoint}.squashfs" -comp xz -Xdict-size 100% -b 1048576 -e "${mountpoint}/system/proc" "${mountpoint}/system/boot" "${mountpoint}/system/tmp" "${mountpoint}/system/sys" "${mountpoint}/system/dev"
done

# Unmounting all mounted filesystems
echo "Unmounting filesystems..."
umount "${BOOT}"
echo "Done."

kpartx -ds "${PROLOLIVE_IMG}"

echo "The end."
