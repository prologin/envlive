#!/bin/sh

# Loading the config
source ./config.sh

# Preventively unmounting filesystems
echo -n "Unmounting previously mounted filesystems, if any..."
umount -R ${PROLOLIVE_DIR}/boot  2>/dev/null
umount -R ${PROLOLIVE_DIR}       2>/dev/null
umount -R overlay-intermediate   2>/dev/null
umount -R ${PROLOLIVE_DIR}.light 2>/dev/null
umount -R ${PROLOLIVE_DIR}.big   2>/dev/null
umount -R ${PROLOLIVE_DIR}.full  2>/dev/null
umount -R *                      2>/dev/null
echo " Done."


# Allocating space for filesystems and the root
echo -n "Allocating filesystems files..."
rm -f ${PROLOLIVE_IMG}.light && fallocate -l 1G            ${PROLOLIVE_IMG}.light
rm -f ${PROLOLIVE_IMG}.big   && fallocate -l 1500M         ${PROLOLIVE_IMG}.big
rm -f ${PROLOLIVE_IMG}.full  && fallocate -l 5G            ${PROLOLIVE_IMG}.full
rm -f ${PROLOLIVE_IMG}       && fallocate -l ${IMAGE_SIZE} ${PROLOLIVE_IMG}
echo " Done."

# Partitionning the image disk file
echo -n "Partitionning the disk image..."
sfdisk ${PROLOLIVE_IMG} < prololive.dos
echo " Done."

# Creating loop devices for the disk image file
echo -n "Generating device mappings for the disk image..."
LOOP=$(kpartx -l ${PROLOLIVE_IMG} | grep -o "loop[0-9]" | head -n1)
rm -f /dev/mapper/${LOOP}
kpartx -as ${PROLOLIVE_IMG}
echo " Done."

# Formatting all filesystems
echo -n "Formatting all filesystems..."
for f in ${PROLOLIVE_IMG}.full ${PROLOLIVE_IMG}.big ${PROLOLIVE_IMG}.light ; do
    mkfs.ext4 -q -F $f
done

mkfs.ext4 -q -F /dev/mapper/${LOOP}p1 -L proloboot
mkfs.ext4 -q -F /dev/mapper/${LOOP}p2 -L persistent
echo " Done."

# Mounting filesystems
echo -n "Mounting filesystems and adding working/ and system/ directories..."
mkdir -p ${PROLOLIVE_DIR}/      # Where all FS will be union-mounted
mkdir -p ${PROLOLIVE_DIR}.light # Where the core OS filesystem will be mounted alone
mkdir -p ${PROLOLIVE_DIR}.big   # Where many light tools will be provided as well as DE/WP
mkdir -p ${PROLOLIVE_DIR}.full  # Where the biggest packages will go. Hi ghc!
mkdir -p overlay-intermediate   # Where .big will be mounted over .light

mount ${PROLOLIVE_IMG}.light ${PROLOLIVE_DIR}.light
mount ${PROLOLIVE_IMG}.big   ${PROLOLIVE_DIR}.big
mount ${PROLOLIVE_IMG}.full  ${PROLOLIVE_DIR}.full

for mountpoint in ${PROLOLIVE_DIR}.light ${PROLOLIVE_DIR}.big ${PROLOLIVE_DIR}.full ; do
    mkdir ${mountpoint}/{work,system} # Creating all of them for harmonization when making squashfs
done
echo " Done."


echo "Installing packages available in repositories..."
echo "Installing core system packages on the lower layer"
mkdir -p ${PROLOLIVE_DIR}.light/system/boot
mount /dev/mapper/${LOOP}p1 ${PROLOLIVE_DIR}.light/system/boot || echo "WTFFFFFFFFFFFFFFF"
./pacstrap -d -C pacman.conf -c ${PROLOLIVE_DIR}.light/system base base-devel
umount /dev/mapper/${LOOP}p1


echo "Installing some not-too-big packages on the middle layer (overlay-intermediate)"
mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.light/system,upperdir=${PROLOLIVE_DIR}.big/system/,workdir=${PROLOLIVE_DIR}.big/work/ overlay-intermediate/
mount /dev/mapper/${LOOP}p1 overlay-intermediate/boot
./pacstrap -C pacman.conf -c overlay-intermediate/ btrfs-progs clang firefox \
	 firefox-i18n-fr grml-zsh-config htop networkmanager openssh \
	 rxvt-unicode screen tmux zsh ntfs-3g lxqt xorg xorg-apps gdb valgrind \
	 js luajit nodejs ocaml php
umount /dev/mapper/${LOOP}p1
umount overlay-intermediate

echo "Installing the biggest packages on the top layer (${PROLOLIVE_DIR})"
mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.big/system:${PROLOLIVE_DIR}.light/system,upperdir=${PROLOLIVE_DIR}.full/system/,workdir=${PROLOLIVE_DIR}.full/work/ ${PROLOLIVE_DIR}
mount /dev/mapper/${LOOP}p1 ${PROLOLIVE_DIR}/boot
./pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}/ clang-analyzer clang-tools-extra \
	 git mercurial ntp reptyr rlwrap rsync samba syslinux wget \
	 codeblocks eclipse ed eric eric-i18n-fr geany kate \
	 kdevelop leafpad mono-debugger monodevelop monodevelop-debugger-gdb \
	 netbeans openjdk8-doc scite boost ghc

# Copying the hook needed to mount squash filesystems on boot
echo -n "Copying hook files..."
cp prolomount.build ${PROLOLIVE_DIR}/usr/lib/initcpio/install/prolomount
cp prolomount.runtime ${PROLOLIVE_DIR}/usr/lib/initcpio/hooks/prolomount
echo " Done."


# Copying config and generating initcpio
echo "Generating the initcpio ramdisk..."
cp mkinitcpio.conf ${PROLOLIVE_DIR}/etc/mkinitcpio.conf
systemd-nspawn -q -D ${PROLOLIVE_DIR} mkinitcpio -p linux
echo "Done."

# Configuring passwords for prologin and root users
echo -n "Configuring users and passwords..."
systemd-nspawn -q -D ${PROLOLIVE_DIR} usermod root -p $(echo ${CANONIQUE} | openssl passwd -1 -stdin) -s /bin/zsh
systemd-nspawn -q -D ${PROLOLIVE_DIR} useradd prologin -G games -m -p $(echo "prologin" | openssl passwd -1 -stdin) -s /bin/zsh
echo " Done."


# Copying the pacman config
cp pacman.conf ${PROLOLIVE_DIR}/etc/pacman.conf


# Installing yaourt and some AUR packages
echo "Installing some AUR packages..."
systemd-nspawn -q -D ${PROLOLIVE_DIR} pacman -S yaourt --noconfirm
echo "prologin ALL=(ALL) NOPASSWD: ALL" >> ${PROLOLIVE_DIR}/etc/sudoers
systemd-nspawn -q -D ${PROLOLIVE_DIR} -u prologin yaourt -S notepadqq-git pycharm-community sublime-text --noconfirm
sed "s:prologin:#prologin:" -i ${PROLOLIVE_DIR}/etc/sudoers
echo "Done."

# Configuring fstab
cat > ${PROLOLIVE_DIR}/etc/fstab <<EOF
LABEL=proloboot /boot                     ext4  defaults 0 0
tmpfs           /var/log                  tmpfs defaults 0 0
tmpfs           /var/cache/pacman         tmpfs defaults 0 0
tmpfs           /home/prologin/.cache     tmpfs defaults 0 0
tmpfs           /home/prologin/ramfs      tmpfs defaults 0 0
EOF


# Configuring system environment
echo "Doing some configuration..."
echo "prololive" > ${PROLOLIVE_DIR}/etc/hostname
systemd-nspawn -q -D ${PROLOLIVE_DIR} ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo 'fr_FR.UTF-8' >  ${PROLOLIVE_DIR}/etc/locale.gen
echo 'en_US.UTF-8' >> ${PROLOLIVE_DIR}/etc/locale.gen
echo "LANG=fr_FR.UTF-8" > ${PROLOLIVE_DIR}/etc/locale.conf
systemd-nspawn -q -D ${PROLOLIVE_DIR} locale-gen

systemd-nspawn -q -D ${PROLOLIVE_DIR} systemctl enable lxdm
systemd-nspawn -q -D ${PROLOLIVE_DIR} sed -i "s:.*\?#.*\?autologin=.\+\?:autologin=prologin:" /etc/lxdm/lxdm.conf

cat > ${PROLOLIVE_DIR}/etc/systemd/journald.conf <<EOF
[Journal]
Storage=none
EOF

# Creating dirs who will be ramfs-mounted
systemd-nspawn -q -D ${PROLOLIVE_DIR} -u prologin mkdir /home/prologin/.cache /home/prologin/ramfs
echo "Done."

# Configuring boot system
echo "Installing syslinux..."
mkdir -p ${PROLOLIVE_DIR}/boot/syslinux
cp -r ${PROLOLIVE_DIR}/usr/lib/syslinux/bios/*.c32 ${PROLOLIVE_DIR}/boot/syslinux/
extlinux --install ${PROLOLIVE_DIR}/boot/syslinux || echo "SOMETHING WENT WRONG."
dd if=${PROLOLIVE_DIR}/usr/lib/syslinux/bios/mbr.bin of=${PROLOLIVE_IMG} bs=440 count=1

cp ${LOGOFILE} ${PROLOLIVE_DIR}/boot/syslinux/${LOGOFILE} || echo -n " missing ${LOGOFILE} file..."
cp syslinux.cfg ${PROLOLIVE_DIR}/boot/syslinux/
echo " Done."

# Creating squash filesystems
echo "Creating squash filesystems..."
for mountpoint in ${PROLOLIVE_DIR}.light ${PROLOLIVE_DIR}.big ${PROLOLIVE_DIR}.full ; do
    mksquashfs ${mountpoint}/system ${PROLOLIVE_DIR}/boot/${mountpoint}.squashfs -comp lz4 -b 1048576 -e ${mountpoint}/system/proc ${mountpoint}/system/tmp ${mountpoint}/system/home ${mountpoint}/system/boot ${mountpoint}/system/dev
done

# Unmounting all mounted filesystems
echo -n "Unmounting filesystems..."
umount -R ${PROLOLIVE_DIR}       # All FS merged minus /boot
umount ${PROLOLIVE_DIR}.full  #
umount overlay-intermediate   # Light and big FS merged
umount ${PROLOLIVE_DIR}.big   #
umount ${PROLOLIVE_DIR}.light #
echo " Done."

echo "The end."
