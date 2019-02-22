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
part_mode='gpt'
aur_cache='pkg_root'

packages_base=( base base-devel syslinux )

packages_intermediate=( boost ed firefox firefox-i18n-fr fpc \
	 gambit-c gcc-ada gdb git grml-zsh-config htop jdk7-openjdk \
	 lxqt lua mono tree \
	 nodejs ntp ntfs-3g ocaml openssh php python \
	 python2 qtcreator rlwrap rxvt-unicode screen sddm tmux ttf-dejavu \
	 valgrind wget xorg xf86-video-intel xorg-apps zsh vim emacs \
	 networkmanager network-manager-applet xterm zeal \
     jre8-openjdk-headless jdk8-openjdk jre8-openjdk)

packages_big=( codeblocks eclipse-java eclipse-ecj eric \
	 geany ghc leafpad netbeans  openjdk7-doc \
	 reptyr rsync samba pycharm-community-edition code atom )

packages_aur=( esotope-bfc-git sublime-text-dev )
