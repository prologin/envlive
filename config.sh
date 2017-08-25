# Envlive, a live environment script for contests.
# Copyright (C) 2016  Alexis Cassaigne <alexis.cassaigne@gmail.com>
# Copyright (C) 2017  Victor Collod <victor.collod@prologin.org>
# Copyright (C) 2017  Association Prologin <info@prologin.org>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

image_size='3824M'
part_mode='dos'
aur_cache='pkg_root'

packages_base=( base base-devel syslinux )

packages_intermediate=( gedit firefox firefox-i18n-fr \
	 gnome-keyring lxqt-notificationd \
	 gdb git grml-zsh-config htop \
	 lxqt-common lxqt-config lxqt-panel lxqt-policykit lxqt-qtplugin \
	 lxqt-runner lxqt-session openbox oxygen-icons pcmanfm-qt \
	 ntp ntfs-3g openssh python \
	 rxvt-unicode screen sddm tmux ttf-dejavu \
	 valgrind wget xorg xf86-video-intel xorg-apps zsh vim emacs \
	  
 	 ipython bpython emacs-python-mode \
	 xfce4-terminal teeworlds \
	 networkmanager network-manager-applet xterm )

packages_big=( rsync samba scite pavucontrol \
	       jupyter mathjax jupyter-notebook )

packages_aur=( pycharm-community sublime-text openarena  python-pygame )
