#!/bin/sh

# Load the config
source ./config.sh

mkemptydir() {
    rm -rf $1
    mkdir $1
}

# Preventively unmount filesystems
echo -n "Unmounting previously mounted filesystems, if any..."
umount -R ${PROLOLIVE_DIR}/boot 2>/dev/null
umount -R ${PROLOLIVE_DIR}      2>/dev/null
umount -R overlay-intermediate  2>/dev/null
umount -R *                     2>/dev/null
kpartx -r ${PROLOLIVE_IMG}      2>/dev/null
echo " Done."


# Allocate space for filesystems and the root
echo "Allocating filesystems files (will not overwrite existing files)..."
rm -f ${PROLOLIVE_IMG}
dd if=/dev/zero of=${PROLOLIVE_IMG} bs=1M count=1 seek=3823
echo "Done."

# Partition the image disk file
echo "Partition the disk image"
sfdisk ${PROLOLIVE_IMG} < prololive.dos

# Create loop devices for the disk image file
echo "Generate device mappings for the disk image..."
LOOP=$(kpartx -av ${PROLOLIVE_IMG} | grep -o "loop[0-9]" | tail -n1)
# To avoid annoying messages about already existing filesystems.
dd if=/dev/zero of=/dev/mapper/${LOOP}p1 bs=1M count=1
dd if=/dev/zero of=/dev/mapper/${LOOP}p2 bs=1M count=1
echo "Done."

mkfs.ext4 /dev/mapper/${LOOP}p1 -L proloboot
mkfs.ext4 /dev/mapper/${LOOP}p2 -L persistent

# Mount filesystems
echo -n "Create mountpoints filesystems..."
mkemptydir ${PROLOLIVE_DIR}/           # Mount the full overlayfs r/w here
mkemptydir ${PROLOLIVE_DIR}.light      # Install only the base system here
mkemptydir ${PROLOLIVE_DIR}.big        # Install interpreters (ghc apart) here, as well as WE/DM
mkemptydir ${PROLOLIVE_DIR}.full       # Intall the biggest packages here
mkemptydir ${PROLOLIVE_DIR}.bind.light # Bind ${PROLOLIVE_DIR}.light/system here
mkemptydir ${PROLOLIVE_DIR}.bind.big   # Bind ${PROLOLIVE_DIR}.big/system here
mkemptydir overlay-intermediate        # Overlay-mount ${PROLOLIVE_DIR}.light and ${PROLOLIVE_DIR}.big

for mountpoint in ${PROLOLIVE_DIR}.light ${PROLOLIVE_DIR}.big ${PROLOLIVE_DIR}.full ; do
    mkdir ${MOUNTPOINT}/{work,system} # Create all of them for harmonization when making squashfs
done

mount -o bind ${PROLOLIVE_DIR}.light/system ${PROLOLIVE_DIR}.bind.light
mount -o bind ${PROLOLIVE_DIR}.big/system ${PROLOLIVE_DIR}.bind.big

echo "Install packages..."
echo "Install core system packages on the lower layer"
ROOT=${PROLOLIVE_DIR}.bind.light
mkdir ${ROOT}/boot
mount /dev/mapper/${LOOP}p1 ${ROOT}/boot
pacstrap -C pacman.conf -c ${ROOT} base base-devel syslinux

# Copy the hook needed to mount squash filesystems on boot
echo -n "Copy hook files..."
cp prolomount.build ${ROOT}/usr/lib/initcpio/install/prolomount
cp prolomount.runtime ${ROOT}/usr/lib/initcpio/hooks/prolomount
echo " Done."


# Copy config and generating initcpio
echo "Generate the initcpio ramdisk..."
cp mkinitcpio.conf ${ROOT}/etc/mkinitcpio.conf
systemd-nspawn -q -D ${ROOT} mkinitcpio -p linux


echo "Install interpreters (GHC apart) and graphical packages on the intermediate layer"
umount /dev/mapper/${LOOP}p1
umount ${ROOT}
ROOT=overlay-intermediate
mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.bind.light,upperdir=${PROLOLIVE_DIR}.big/system,workdir=${PROLOLIVE_DIR}.big/work ${ROOT} || exit 42
mount /dev/mapper/${LOOP}p1 ${ROOT}/boot
pacstrap -C pacman.conf -c ${ROOT}/ boost ed firefox firefox-i18n-fr \
	 fpc gambit-c gcc-ada gdb git grml-zsh-config htop jdk7-openjdk lxqt \
	 luajit mono mono-basic mono-debugger networkmanager nodejs ntp ntfs-3g \
	 ocaml openssh php python python2 rlwrap rxvt-unicode screen sddm tmux \
	 valgrind wget xorg xorg-apps zsh

umount /dev/mapper/${LOOP}p1
umount ${ROOT}

echo "Install remaining and big packages on the top layer (${PROLOLIVE_DIR})"
ROOT=${PROLOLIVE_DIR}
mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.bind.big:${PROLOLIVE_DIR}.bind.light,upperdir=${PROLOLIVE_DIR}.full/system/,workdir=${PROLOLIVE_DIR}.full/work/ ${ROOT} || exit 42
mount /dev/mapper/${LOOP}p1 ${ROOT}/boot
pacstrap -C pacman.conf -c ${ROOT}/ codeblocks eclipse eric \
	 esotope-bfc-git eric-i18n-fr fsharp geany ghc kate kdevelop \
	 leafpad mercurial monodevelop monodevelop-debugger-gdb netbeans \
	 notepadqq-bin openjdk7-doc pycharm-community reptyr rsync \
	 samba scite

# Configure system environment
echo "System configuration..."
echo "prololive" > ${ROOT}/etc/hostname
systemd-nspawn -q -D ${ROOT} ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo 'fr_FR.UTF-8 UTF-8' >  ${ROOT}/etc/locale.gen
echo 'en_US.UTF-8 UTF-8' >> ${ROOT}/etc/locale.gen
echo "LANG=fr_FR.UTF-8"  >  ${ROOT}/etc/locale.conf
echo "KEYMAP=fr-pc"      >  ${ROOT}/etc/vconsole.conf
systemd-nspawn -q -D ${ROOT} locale-gen
cp sddm.conf ${ROOT}/etc/
systemd-nspawn -q -D ${ROOT} systemctl enable sddm
systemd-nspawn -q -D ${ROOT} systemctl enable NetworkManager
cp 00-keyboard.conf ${ROOT}/etc/X11/xorg.conf.d/
cp .Xresources ${ROOT}/etc/skel/
echo 'alias ocaml="rlwrap ocaml"' >> /etc/skel/.zshrc
echo 'source /etc/profile.d/jre.sh' >> /etc/skel/.zshrc

cat > ${ROOT}/etc/systemd/journald.conf <<EOF
[Journal]
Storage=volatile
EOF

# Configure passwords for prologin and root users
echo -n "Configuring users and passwords..."
systemd-nspawn -q -D ${ROOT} usermod root -p $(echo ${CANONIQUE} | openssl passwd -1 -stdin) -s /bin/zsh
systemd-nspawn -q -D ${ROOT} useradd prologin -G games -m -p $(echo "prologin" | openssl passwd -1 -stdin) -s /bin/zsh
echo " Done."


# Copy the pacman config
cp pacman.conf ${ROOT}/etc/pacman.conf


# Configure fstab
cat > ${ROOT}/etc/fstab <<EOF
LABEL=proloboot /boot                     ext4  defaults 0 0
tmpfs           /home/prologin/.cache     tmpfs defaults 0 0
tmpfs           /home/prologin/ramfs      tmpfs defaults 0 0
EOF


# Create dirs who will be ramfs-mounted
systemd-nspawn -q -D ${ROOT} -u prologin mkdir /home/prologin/.cache /home/prologin/ramfs

# Configure boot system
echo -n "Installing syslinux..."
dd if=${ROOT}/usr/lib/syslinux/bios/mbr.bin of=/dev/${LOOP} bs=440 count=1
mkdir -p ${ROOT}/boot/syslinux
cp -r ${ROOT}/usr/lib/syslinux/bios/*.c32 ${ROOT}/boot/syslinux/
extlinux --device /dev/mapper/${LOOP}p1 --install ${ROOT}/boot/syslinux

cp logo.png ${ROOT}/boot/syslinux/ || echo -n " missing logo.png file..."
cp syslinux.cfg ${ROOT}/boot/syslinux/
echo " Done."

# Creating squash filesystems
echo "Create squash filesystems..."
for mountpoint in ${PROLOLIVE_DIR}.light ${PROLOLIVE_DIR}.big ${PROLOLIVE_DIR}.full ; do
    mksquashfs ${mountpoint}/system ${PROLOLIVE_DIR}/boot/${mountpoint}.squashfs -comp xz -Xdict-size 100% -b 1048576 -e ${mountpoint}/system/proc ${mountpoint}/system/tmp ${mountpoint}/system/boot ${mountpoint}/system/dev
done

cp documentation.squashfs ${ROOT}/boot/

# Unmounting all mounted filesystems
echo -n "Unmounting filesystems..."
umount -R ${PROLOLIVE_DIR}
umount ${PROLOLIVE_DIR}.full
umount ${PROLOLIVE_DIR}.big
umount ${PROLOLIVE_DIR}.light
umount ${PROLOLIVE_DIR}.bind.light
umount ${PROLOLIVE_DIR].bind.big
echo " Done."

echo "The end."
