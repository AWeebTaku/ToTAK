#!/bin/sh
# Lays out the files every native package (deb, rpm, arch) installs.
# Usage: stage.sh <exported-binary> <output-dir>
set -eu
bin=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)

rm -rf "$out"
install -Dm755 "$bin" "$out/usr/lib/totak/ToTAK.x86_64"
install -dm755 "$out/usr/bin"
ln -s ../lib/totak/ToTAK.x86_64 "$out/usr/bin/totak"
install -Dm644 "$here/totak-system.desktop" "$out/usr/share/applications/totak.desktop"
install -Dm644 "$root/assets/icon.png" "$out/usr/share/icons/hicolor/256x256/apps/totak.png"
# NOTE: never strip this binary. Godot appends the game data (.pck) to it, and stripping would corrupt it.
