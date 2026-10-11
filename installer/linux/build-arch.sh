#!/bin/sh
# Arch Linux package. Must run as a normal user (makepkg refuses root).
# Usage: build-arch.sh <version> <exported-binary> <output.pkg.tar.zst>
set -eu
version=$1
bin=$2
outfile=$3
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$here/stage.sh" "$bin" "$work/stage"
cp "$here/PKGBUILD" "$work/PKGBUILD"
(
  cd "$work"
  TOTAK_VERSION=$version TOTAK_STAGE=$work/stage TOTAK_LICENSE=$here/../../LICENSE \
    PKGDEST=$work/out makepkg --force --nodeps --nocheck --skipinteg
)
mkdir -p "$(dirname "$outfile")"
cp "$work"/out/totak-*.pkg.tar.zst "$outfile"
