#!/bin/bash
# Lumi OS: Fedora Silverblue from Universal Blue with Lumi built in.

set -ouex pipefail

# Wallpaper, GNOME defaults and Lumi's autostart for new accounts.
cp -avf "/ctx/system_files"/. /

# Lumi itself: the .rpm for this CPU (x86_64 or aarch64) from the latest release, with its dependencies from Fedora.
arch=$(uname -m)
rpm_url=$(curl -fsSL https://api.github.com/repos/AlbertS15/Lumi/releases/latest |
  grep -o "\"browser_download_url\": *\"[^\"]*-${arch}\\.rpm\"" | cut -d'"' -f4 | head -n1) || true
if [ -z "$rpm_url" ]; then
  echo "Found no ${arch} .rpm in the latest Lumi release" >&2
  exit 1
fi
dnf5 install -y "$rpm_url" plocate
test -x /usr/bin/lumi
test "$(rpm -q --qf '%{ARCH}' lumi-launcher)" = "$arch"

# The Fedora logo in the corner of the desktop; Lumi OS has its own wallpaper.
dnf5 remove -y gnome-shell-extension-background-logo || true

# Apply the GNOME defaults above.
glib-compile-schemas /usr/share/glib-2.0/schemas

# The name in Settings → About and the boot menu. ID stays fedora, so tools that check for Fedora keep working.
sed -i \
  -e 's/^NAME=.*/NAME="Lumi OS"/' \
  -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Lumi OS"/' \
  -e 's|^HOME_URL=.*|HOME_URL="https://github.com/AlbertS15/lumi-os"|' \
  -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/AlbertS15/lumi-os/issues"|' \
  /usr/lib/os-release
grep -q '^VARIANT_ID=' /usr/lib/os-release && sed -i 's/^VARIANT_ID=.*/VARIANT_ID=lumi-os/' /usr/lib/os-release || echo 'VARIANT_ID=lumi-os' >> /usr/lib/os-release

# plocate's index refreshes daily, so Lumi finds files by name.
systemctl enable plocate-updatedb.timer
