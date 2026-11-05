#!/bin/bash
# Lumi OS: Fedora Silverblue from Universal Blue with Lumi built in.

set -ouex pipefail

# Wallpaper, GNOME defaults and Lumi's autostart for new accounts.
cp -avf "/ctx/system_files"/. /

# Lumi itself: the .rpm for this CPU (x86_64 or aarch64) from the latest release, with its
# dependencies from Fedora. CI puts it in build_files/lumi-rpm/ (cached per release, see
# .github/actions/lumi-rpm). A local build without it fetches it through the API asset endpoint,
# which, unlike the browser download link, does not add to the release's public download counter.
arch=$(uname -m)
lumi_rpm=$(ls /ctx/lumi-rpm/*"${arch}".rpm 2>/dev/null | head -1 || true)
if [[ -z $lumi_rpm ]]; then
  # x86_64: the latest stable release. aarch64: the newest release with an aarch64 rpm, pre-releases too.
  api=https://api.github.com/repos/AlbertS15/Lumi/releases/latest
  [[ $arch == x86_64 ]] || api='https://api.github.com/repos/AlbertS15/Lumi/releases?per_page=20'
  asset_url=$(curl -fsSL "$api" | ARCH="$arch" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
rels = [d] if isinstance(d, dict) else [r for r in d if not r["draft"]]
print(next((a["url"] for r in rels for a in r["assets"] if a["name"].endswith(os.environ["ARCH"] + ".rpm")), ""))')
  if [[ -z $asset_url ]]; then
    echo "Found no ${arch} .rpm in the latest Lumi release" >&2
    exit 1
  fi
  lumi_rpm=/tmp/lumi-launcher.${arch}.rpm
  curl -fsSL -H 'Accept: application/octet-stream' -o "$lumi_rpm" "$asset_url"
fi
dnf5 install -y "$lumi_rpm" plocate
test -x /usr/bin/lumi
test "$(rpm -q --qf '%{ARCH}' lumi-launcher)" = "$arch"

# The Fedora logo in the corner of the desktop; Lumi OS has its own wallpaper.
dnf5 remove -y gnome-shell-extension-background-logo || true

# Packages only the "GNOME Classic" login session uses (Lumi OS ships the normal GNOME session):
# the session itself and its four shell extensions. gnome-tour stays: GNOME Shell's first-login
# "Welcome" dialog offers it, and removing it saved nothing measurable. Only what is installed is removed.
cut=()
for p in gnome-classic-session gnome-shell-extension-apps-menu gnome-shell-extension-launch-new-instance \
  gnome-shell-extension-places-menu gnome-shell-extension-window-list; do
  rpm -q "$p" >/dev/null 2>&1 && cut+=("$p")
done
((${#cut[@]})) && dnf5 remove -y "${cut[@]}"
dnf5 clean all

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

# Branding: Lumi logo in Settings → About, first setup and the login screen.
# os-release LOGO= names the icon (installed in hicolor by system_files).
sed -i '/^LOGO=/d' /usr/lib/os-release
echo 'LOGO=lumi-logo' >> /usr/lib/os-release
# Anything that still asks for the Fedora logo files gets the Lumi ghost of the same size.
for f in $(find /usr/share/icons /usr/share/pixmaps -type f \( -name 'fedora-logo*' -o -name 'fedora-gdm-logo*' -o -name 'system-logo*' -o -name 'fedora_logo*' \) \
    -name '*.png' 2>/dev/null); do
  size=$(basename "$(dirname "$(dirname "$f")")" | grep -o '^[0-9]*' || true)
  case "$f" in
    */pixmaps/*) cp -f /usr/share/pixmaps/lumi-logo.png "$f" ;;
    *) [ -n "$size" ] && [ -f "/usr/share/icons/hicolor/${size}x${size}/apps/lumi-logo.png" ] \
         && cp -f "/usr/share/icons/hicolor/${size}x${size}/apps/lumi-logo.png" "$f" ;;
  esac
done
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# GDM login screen settings (dconf database "gdm" is part of GDM's profile).
dconf update

# Boot splash: the script plugin the theme needs is a separate package.
dnf5 install -y plymouth-plugin-script

# Make Lumi the default Plymouth theme and rebuild the initramfs, which bootc boots from.
plymouth-set-default-theme lumi
kver=$(cd /usr/lib/modules && echo *)
DRACUT_NO_XATTR=1 dracut --no-hostonly --kver "$kver" --reproducible --add "ostree plymouth" -f "/usr/lib/modules/$kver/initramfs.img"
chmod 0600 "/usr/lib/modules/$kver/initramfs.img"

# Firefox in Russian: the langpacks are installed, and Firefox follows the system language (set in first setup).
if rpm -q firefox >/dev/null 2>&1; then
  dnf5 install -y firefox-langpacks
fi
