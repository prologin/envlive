#!/bin/sh
PROLOLIVE_DIR=prololive
PROLOLIVE_IMG=prololive.img
CANONIQUE=fu
LOGOFILE=logo.png
USER_NAME=prologin
IMAGE_SIZE_IN_MiB=3824
TMPIMG_SIZE_IN_MiB=9001

test -e ${PROLOLIVE_IMG}.lowmem  || dd if=/dev/zero of=${PROLOLIVE_IMG}.lowmem bs=1M count=1000
test -e ${PROLOLIVE_IMG}.highmem || dd if=/dev/zero of=${PROLOLIVE_IMG}.highmem bs=1M count=1500
#test -e ${PROLOLIVE_IMG}.fullmem || dd if=/dev/zero of=${PROLOLIVE_IMG}.fullmem bs=1M count=5000

umount -R ${PROLOLIVE_DIR}.lowmem
umount -R ${PROLOLIVE_DIR}.highmem
#umount -R ${PROLOLIVE_DIR}.fullmem

mkfs.ext4 -F ${PROLOLIVE_IMG}.lowmem
mkfs.ext4 -F ${PROLOLIVE_IMG}.highmem
#mkfs.ext4 -F ${PROLOLIVE_IMG}.fullmem

cat > pacman.conf <<EOF
[options]
HoldPkg     = pacman glibc
Architecture = i686
Color
CheckSpace
ILoveCandy
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[archlinuxfr]
SigLevel = Optional TrustAll
Server = http://repo.archlinux.fr/\$arch

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist
EOF

mkdir -p ${PROLOLIVE_DIR}.lowmem
mkdir -p ${PROLOLIVE_DIR}.highmem
#mkdir -p ${PROLOLIVE_DIR}.fullmem

mkdir -p overlay-highmem
#mkdir -p overlay-fullmem

mount ${PROLOLIVE_IMG}.lowmem ${PROLOLIVE_DIR}.lowmem

mount ${PROLOLIVE_IMG}.highmem overlay-highmem
mkdir -p overlay-highmem/work
mkdir -p overlay-highmem/system

#mount ${PROLOLIVE_IMG}.fullmem overlay-fullmem
#mkdir -p overlay-fullmem/work
#mkdir -p overlay-fullmem/system

mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.lowmem/,upperdir=overlay-highmem/system/,workdir=overlay-highmem/work/ ${PROLOLIVE_DIR}.highmem/
#mount -t overlay overlay -o lowerdir=${PROLOLIVE_DIR}.highmem,upperdir=overlay-fullmem/system/,workdir=overlay-highmem/work/ ${PROLOLIVE_DIR}.fullmem/

pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}.lowmem base base-devel

pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}.highmem btrfs-progs \
	 clang firefox firefox-i18n-fr grml-zsh-config htop networkmanager \
	 openssh rxvt-unicode screen tmux zsh ntfs-3g lxqt xorg \
	 xorg-apps gdb valgrind js luajit nodejs ocaml php

#pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}.fullmem clang-analyzer \
#	 clang-tools-extra git mercurial ntp \
#	 reptyr rlwrap rsync samba syslinux wget \
#	 sublime-text codeblocks eclipse ed eric eric-i18n-fr geany kate \
#	 kdevelop leafpad mono-debugger monodevelop monodevelop-debugger-gdb \
#	 netbeans openjdk8-doc scite boost ghc

rm -f *.squashfs

mksquashfs ${PROLOLIVE_DIR}.lowmem/ prololive-lowmem.squashfs -comp lz4 -b 1048576 -e ${PROLOLIVE_DIR}.lowmem/proc ${PROLOLIVE_DIR}.lowmem/tmp ${PROLOLIVE_DIR}.lowmem/home ${PROLOLIVE_DIR}.lowmem/boot ${PROLOLIVE_DIR}.lowmem/dev
mksquashfs overlay-highmem/ prololive-highmem.squashfs -comp lz4 -b 1048576 -e overlay-highmem/proc overlay-highmem/tmp overlay-highmem/home overlay-highmem/boot overlay-highmem/dev
#mksquashfs overlay-fullmem/ prololive-fullmem.squashfs -comp xz -b 1048576 -e overlay-fullmem/proc overlay-fullmem/tmp overlay-fullmem/home overlay-fullmem/boot overlay-fullmem/dev


#umount ${PROLOLIVE_DIR}.fullmem # OverlayFS
#umount overlay-fullmem          # FS joined with another one
umount ${PROLOLIVE_DIR}.highmem # OverlayFS
umount overlay-highmem/         # FS joined with another one
umount ${PROLOLIVE_DIR}.lowmem  # Base filesystem

exit 0

systemd-nspawn -q -D ${PROLOLIVE_DIR} usermod root -p $(echo ${CANONIQUE} | openssl passwd -1 -stdin) -s /bin/zsh
systemd-nspawn -q -D ${PROLOLIVE_DIR} useradd ${USER_NAME} -G games -m -p $(echo "${USER_NAME}" | openssl passwd -1 -stdin) -s /bin/zsh

cp pacman.conf ${PROLOLIVE_DIR}/etc/pacman.conf

sed -i "s/PKGEXT='.pkg.tar.xz'/PKGEXT='.pkg.tar'/" ${PROLOLIVE_DIR}/etc/makepkg.conf

systemd-nspawn -q -D ${PROLOLIVE_DIR} pacman -S yaourt --noconfirm
echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> ${PROLOLIVE_DIR}/etc/sudoers
systemd-nspawn -q -D ${PROLOLIVE_DIR} -u ${USER_NAME} yaourt -S notepadqq-git pycharm-community --noconfirm
sed "s:${USER_NAME}:#${USER_NAME}:" -i ${PROLOLIVE_DIR}/etc/sudoers

cat > ${PROLOLIVE_DIR}/etc/fstab <<EOF
LABEL=prolohome /home                     btrfs defaults,noatime,compress-force=zlib,ssd,discard,space_cache,autodefrag,commit=3 0 0
LABEL=proloboot /boot                     ext4  defaults                                                                         0 0
tmpfs           /var/log                  tmpfs defaults                                                                         0 0
tmpfs           /var/cache/pacman         tmpfs defaults                                                                         0 0
tmpfs           /home/${USER_NAME}/.cache tmpfs defaults                                                                         0 0
tmpfs           /home/${USER_NAME}/ramfs  tmpfs defaults                                                                         0 0
EOF

echo "prololive" > ${PROLOLIVE_DIR}/etc/hostname
systemd-nspawn -q -D ${PROLOLIVE_DIR} ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo 'fr_FR.UTF-8' >> ${PROLOLIVE_DIR}/etc/locale.gen
echo "LANG=fr_FR.UTF-8" > ${PROLOLIVE_DIR}/etc/locale.conf
systemd-nspawn -q -D ${PROLOLIVE_DIR} locale-gen

systemd-nspawn -q -D ${PROLOLIVE_DIR} mkinitcpio -p linux

systemd-nspawn -q -D ${PROLOLIVE_DIR} -u ${USER_NAME} mkdir /home/${USER_NAME}/.cache /home/${USER_NAME}/ramfs

ln -s /dev/${LOOP} /dev/mapper/${LOOP}
syslinux-install_update -iam -c ${PROLOLIVE_DIR}
rm /dev/mapper/${LOOP}

cp ${LOGOFILE} ${PROLOLIVE_DIR}/boot/syslinux/logo.png
cat > ${PROLOLIVE_DIR}/boot/syslinux/syslinux.cfg <<EOF
DEFAULT arch
PROMPT 0
TIMEOUT 10
UI vesamenu.c32

MENU TITLE Arch Linux
MENU BACKGROUND logo.png
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL Arch Linux Prologin Edition
    MENU LABEL Arch Linux
    LINUX ../vmlinuz-linux
    APPEND root=LABEL=prololive ro
    INITRD ../initramfs-linux-fallback.img

LABEL hdt
	MENU LABEL Hardware Detection Tool
	COM32 hdt.c32

LABEL reboot
	MENU LABEL Reboot
	COM32 reboot.c32

LABEL poweroff
	MENU LABEL Poweroff
	COM32 poweroff.c32
EOF

systemd-nspawn -q -D ${PROLOLIVE_DIR} systemctl enable lxdm
systemd-nspawn -q -D ${PROLOLIVE_DIR} sed -i "s:.*\?#.*\?autologin=.\+\?:autologin=${USER_NAME}:" /etc/lxdm/lxdm.conf

cp -a prologin/documentation ${PROLOLIVE_DIR}/home/${USER_NAME}/

sync

cat > ${PROLOLIVE_DIR}/etc/systemd/journald.conf <<EOF
[Journal]
Storage=none
EOF

duperemove -dhrxb8k ${PROLOLIVE_DIR}

umount -R ${PROLOLIVE_DIR}
kpartx -d ${PROLOLIVE_IMG}
