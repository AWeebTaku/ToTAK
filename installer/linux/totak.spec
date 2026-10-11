# RPM package for Fedora, openSUSE, RHEL and friends.
# Build: rpmbuild -bb --define "pkgver 1.2.3" --define "stagedir /path" --define "licensefile /path/LICENSE" ...
# The game binary has its data appended to it, so it must NOT be stripped or post-processed.
%global debug_package %{nil}
%global __strip /bin/true
%global __os_install_post %{nil}
%global _build_id_links none

Name:           totak
Version:        %{pkgver}
Release:        1
Summary:        Pixel-art horror roguelike dungeon crawler
License:        MIT
URL:            https://github.com/AWeebTaku/ToTAK
BuildArch:      x86_64
Requires:       libGL.so.1()(64bit)
Requires:       libX11.so.6()(64bit)
Requires:       libXcursor.so.1()(64bit)
Requires:       libXi.so.6()(64bit)
Requires:       libXinerama.so.1()(64bit)
Requires:       libXrandr.so.2()(64bit)

%description
Tombs of the Ancient Kings is a pixel-art horror roguelike. Descend through endless
tombs with a single guttering torch, fight ghouls and abominations, and see how deep
you can get before the dark claims you.

%prep

%build

%install
mkdir -p %{buildroot}
cp -a %{stagedir}/. %{buildroot}/
install -Dm644 %{licensefile} %{buildroot}/usr/share/licenses/totak/LICENSE

%files
%license /usr/share/licenses/totak/LICENSE
/usr/bin/totak
/usr/lib/totak
/usr/share/applications/totak.desktop
/usr/share/icons/hicolor/256x256/apps/totak.png
