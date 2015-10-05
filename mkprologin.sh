#!/bin/sh
PROLOLIVE_DIR=prololive
PROLOLIVE_IMG=prololive.img
CANONIQUE=fu
LOGOFILE=logo.png
USER_NAME=prologin
IMAGE_SIZE_IN_MiB=3824
TMPIMG_SIZE_IN_MiB=10000

umount -R ${PROLOLIVE_DIR} 2>/dev/null
kpartx -d ${PROLOLIVE_IMG} 2>/dev/null

mkdir -p ${PROLOLIVE_DIR}
dd if=/dev/zero of=${PROLOLIVE_IMG}.tmp bs=1M count=${TMPIMG_SIZE_IN_MiB}
mkfs.ext4 ${PROLOLIVE_IMG}.tmp

dd if=/dev/zero of=${PROLOLIVE_IMG} bs=1M count=${IMAGE_SIZE_IN_MiB}
sfdisk ${PROLOLIVE_IMG} << EOF
label: dos
label-id: 0x574085f1
device: ${PROLOLIVE_IMG}
unit: sectors
${PROLOLIVE_IMG}1 : start= 2048,   size= 262144, type=83, bootable
${PROLOLIVE_IMG}2 : start= 264192, size=7567360, type=83
EOF

LOOP=$(kpartx -l ${PROLOLIVE_IMG} | grep -o "loop[0-9]" | head -n1)
rm -f /dev/mapper/${LOOP}
kpartx -as ${PROLOLIVE_IMG}

mkfs.ext4 /dev/mapper/${LOOP}p1 -L proloboot
mkfs.btrfs /dev/mapper/${LOOP}p2 -L prololive
mount /dev/mapper/${LOOP}p2 ${PROLOLIVE_DIR} -o rw,noatime,compress-force=zlib,ssd,space_cache,autodefrag,commit=3,discard
mkdir ${PROLOLIVE_DIR}/boot
mount /dev/mapper/${LOOP}p1 ${PROLOLIVE_DIR}/boot -o discard,noatime,commit=1

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
Server = http://repo.archlinux.fr/$arch

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist
EOF

mkdir ${PROLOLIVE_DIR}.base

pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}.base base base-devel btrfs-progs clang grml-zsh-config htop networkmanager ntfs-3g readline rxvt-unicode screen tmux ttf-dejavu xfce4 xorg xorg-apps zsh
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR}.base emacs vim gdb valgrind js luajit 



mksquashfs



pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} clang-analyzer clang-tools-extra firefox firefox-i18n-fr git mercurial ntp openssh reptyr rlwrap rsync samba syslinux wget
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} sublime-text codeblocks eclipse ed eric eric-i18n-fr
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} geany kate kdevelop leafpad mono-debugger monodevelop monodevelop-debugger-gdb
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} netbeans openjdk8-doc scite
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} boost nodejs ocaml php
pacstrap -C pacman.conf -c ${PROLOLIVE_DIR} ghc

systemd-nspawn -q -D ${PROLOLIVE_DIR} usermod root -p $(echo ${CANONIQUE} | openssl passwd -1 -stdin) -s /bin/zsh
systemd-nspawn -q -D ${PROLOLIVE_DIR} useradd ${USER_NAME} -G games -m -p $(echo "${USER_NAME}" | openssl passwd -1 -stdin) -s /bin/zsh

cp pacman.conf ${PROLOLIVE_DIR}/etc/pacman.conf

sed -i "s/PKGEXT='.pkg.tar.xz'/PKGEXT='.pkg.tar'/" ${PROLOLIVE_DIR}/etc/makepkg.conf

systemd-nspawn -q -D ${PROLOLIVE_DIR} pacman -S yaourt --noconfirm
echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> ${PROLOLIVE_DIR}/etc/sudoers
systemd-nspawn -q -D ${PROLOLIVE_DIR} -u ${USER_NAME} yaourt -S notepadqq-git pycharm-community --noconfirm
sed "s:${USER_NAME}:#${USER_NAME}:" -i ${PROLOLIVE_DIR}/etc/sudoers

echo "LABEL=prololive / btrfs rw,noatime,compress-force=zlib,ssd,discard,space_cache,autodefrag,commit=3 0 0" >> ${PROLOLIVE_DIR}/etc/fstab
echo "LABEL=proloboot /boot ext4 defaults 0 0" >> ${PROLOLIVE_DIR}/etc/fstab
echo "tmpfs /var/log tmpfs defaults 0 0" >> ${PROLOLIVE_DIR}/etc/fstab
echo "tmpfs /var/cache/pacman tmpfs defaults 0 0" >> ${PROLOLIVE_DIR}/etc/fstab
echo "tmpfs /home/${USER_NAME}/.cache tmpfs defaults 0 0" >> ${PROLOLIVE_DIR}/etc/fstab
echo "tmpfs /home/${USER_NAME}/ramfs tmpfs defaults 0 0" >> ${PROLOLIVE_DIR}/etc/fstab

echo "prololive" > ${PROLOLIVE_DIR}/etc/hostname
systemd-nspawn -q -D ${PROLOLIVE_DIR} ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo 'fr_FR.UTF-8' >> ${PROLOLIVE_DIR}/etc/locale.gen
systemd-nspawn -q -D ${PROLOLIVE_DIR} locale-gen
echo "LANG=fr_FR.UTF-8" > ${PROLOLIVE_DIR}/etc/locale.conf

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
