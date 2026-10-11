#!/bin/sh
# Fedora / openSUSE / RHEL package.  Usage: build-rpm.sh <version> <exported-binary> <output.rpm>
set -eu
version=$1
bin=$2
outfile=$3
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$here/stage.sh" "$bin" "$work/stage"
rpmbuild -bb "$here/totak.spec" \
  --define "_topdir $work/rpmbuild" \
  --define "pkgver $version" \
  --define "stagedir $work/stage" \
  --define "licensefile $here/../../LICENSE" \
  --target x86_64
mkdir -p "$(dirname "$outfile")"
cp "$work"/rpmbuild/RPMS/x86_64/totak-*.rpm "$outfile"
