#!/bin/bash
# Runs INSIDE the test VM, before GDM starts, and only there: run.sh hands it to the VM as a systemd credential
# (QEMU SMBIOS type 11), so the shipped image never contains it. It makes a test account that GDM logs into on its
# own and lets the test runner in over SSH.

set -euxo pipefail

user=lumitest

# A regular account, made the way GNOME's first setup makes one: home copied from /etc/skel (with Lumi's autostart).
if ! id "$user" &>/dev/null; then
  useradd --create-home --comment "Lumi Test" --groups wheel "$user"
fi
passwd --delete "$user"
home=$(getent passwd "$user" | cut -d: -f6)

# Skip GNOME's first-login setup for the account.
install -d -o "$user" -g "$user" "$home/.config"
echo yes > "$home/.config/gnome-initial-setup-done"
chown "$user:$user" "$home/.config/gnome-initial-setup-done"

# GDM logs the account in without a password.
conf=/etc/gdm/custom.conf
mkdir -p /etc/gdm
touch "$conf"
sed -i '/^AutomaticLogin/d' "$conf"
if grep -q '^\[daemon\]' "$conf"; then
  sed -i "/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=$user" "$conf"
else
  printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=%s\n' "$user" >> "$conf"
fi
cat "$conf"

# SSH for the test runner: root with the key run.sh generated for this run.
root_home=$(getent passwd root | cut -d: -f6)
install -d -m 700 "$root_home/.ssh"
install -m 600 "$CREDENTIALS_DIRECTORY/lumi-test.ssh-key" "$root_home/.ssh/authorized_keys"
restorecon -RF "$root_home/.ssh" || true
systemctl start --no-block sshd.service
