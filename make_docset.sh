# Envlive, a live environment script for contests.
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

. ./logging.sh

zeal_languages=(
    C
    PHP
    C++
    Haskell
    Java_SE8
    Python_2
    Python_3
    OCaml
    JavaScript
    Lua_5.3
    Perl
    NET_Framework
)

mkdir -p docs
for lang in ${zeal_languages[@]}; do
    [[ ! -d "docs/${lang}.docset" ]] || continue
    log "Downloading ${lang}..."
    curl "http://london.kapeli.com/feeds/${lang}.tgz" | tar xz -C docs/ --
done

#log "Building the documentation squashfs..."
#mksquashfs docs documentation.squashfs -comp xz -Xdict-size 100% -b 1048576
