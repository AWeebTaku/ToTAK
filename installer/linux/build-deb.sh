#!/bin/sh
# Debian / Ubuntu / Mint package.  Usage: build-deb.sh <version> <exported-binary> <output.deb>
set -eu
version=$1
bin=$2
outfile=$3
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$here/stage.sh" "$bin" "$work/pkg"
install -Dm644 "$here/../../LICENSE" "$work/pkg/usr/share/doc/totak/copyright"
mkdir "$work/pkg/DEBIAN"
cat > "$work/pkg/DEBIAN/control" <<CONTROL
Package: totak
Version: $version
Section: games
Priority: optional
Architecture: amd64
Maintainer: ToTAK maintainers <noreply@users.noreply.github.com>
Installed-Size: $(du -sk "$work/pkg/usr" | cut -f1)
Depends: libc6
Recommends: libgl1, libx11-6, libxcursor1, libxi6, libxinerama1, libxrandr2, libasound2 | libasound2t64 | libpulse0
Homepage: https://github.com/AWeebTaku/ToTAK
Description: Tombs of the Ancient Kings
 A pixel-art horror roguelike dungeon crawler. Descend through endless
 tombs with a single guttering torch, fight ghouls and abominations, and
 see how deep you can get before the dark claims you.
CONTROL
mkdir -p "$(dirname "$outfile")"
dpkg-deb --root-owner-group -Zxz --build "$work/pkg" "$outfile"
