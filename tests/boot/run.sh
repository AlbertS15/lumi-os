#!/bin/bash
# Boot test for a Lumi OS disk image: boots the qcow2 in QEMU/KVM with UEFI, lets GDM log a test account in on its
# own, and checks that the desktop comes up with Lumi running and its Ctrl+Space shortcut working.
#
#   tests/boot/run.sh path/to/disk.qcow2 [output-dir]
#
# The image is not changed. QEMU boots a throwaway overlay of it, and the test-only setup (test account, GDM
# autologin, SSH key) reaches the VM as systemd credentials over SMBIOS, which systemd reads at boot and which exist
# only in this VM. Needs: qemu-system-x86_64 with KVM, OVMF, qemu-img, socat, ssh, ImageMagick, python3.
# Exits non-zero when any check fails; screenshots and logs land in the output directory.

set -uo pipefail

disk=$(realpath "${1:?usage: run.sh disk.qcow2 [output-dir]}")
out=$(realpath -m "${2:-boot-test-output}")
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out/screenshots" "$out/logs"
work=$(mktemp -d)

user=lumitest
ssh_port=2222
mon_sock=$work/monitor.sock
ovmf_code=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}
ovmf_vars=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
boot_timeout=${BOOT_TIMEOUT:-900}

failures=0
results=$out/results.txt
: > "$results"

log() { echo "[$(date -u +%H:%M:%S)] $*" >&2; }
pass() { echo "PASS  $1${2:+ — $2}" | tee -a "$results" >&2; }
fail() { echo "FAIL  $1${2:+ — $2}" | tee -a "$results" >&2; failures=$((failures + 1)); }
note() { echo "NOTE  $*" | tee -a "$results" >&2; }

# QEMU's human monitor.
mon() { printf '%s\n' "$*" | socat -t 3 - "UNIX-CONNECT:$mon_sock" >/dev/null 2>&1; }

shot_n=0
last_shot=""
# Saves what the VM's screen shows as screenshots/NN-name.png, its path in $last_shot ("" when it failed).
shot() {
  shot_n=$((shot_n + 1))
  local name ppm png
  name=$(printf '%02d-%s' "$shot_n" "$1")
  ppm=$work/$name.ppm
  png=$out/screenshots/$name.png
  rm -f "$ppm"
  last_shot=""
  mon "screendump $ppm"
  for _ in $(seq 20); do
    [[ -s $ppm ]] && break
    sleep 0.5
  done
  sleep 1
  if [[ -s $ppm ]] && convert "$ppm" "$png" 2>/dev/null; then
    last_shot=$png
  else
    log "screendump $name failed"
  fi
}

key=$work/id_ed25519
ssh_opts=(-i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
  -o ConnectTimeout=5 -o BatchMode=yes)
vm() { ssh "${ssh_opts[@]}" root@127.0.0.1 "$@"; }
# A command in the test account's desktop session (its D-Bus, so gsettings and gdbus talk to the running GNOME).
as_user() {
  vm "uid=\$(id -u $user); runuser -u $user -- env XDG_RUNTIME_DIR=/run/user/\$uid \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$uid/bus $*"
}

# Retries a command until it succeeds or the time (seconds) runs out.
wait_for() {
  local timeout=$1
  shift
  local end=$((SECONDS + timeout))
  until "$@"; do
    ((SECONDS >= end)) && return 1
    sleep 5
  done
}

cleanup() {
  if [[ -f $work/qemu.pid ]]; then
    mon quit
    sleep 2
    kill "$(cat "$work/qemu.pid")" 2>/dev/null
  fi
  cp -f "$work/serial.log" "$out/logs/serial.log" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

# --- Test-only setup, handed over as systemd credentials --------------------------------------------------------

ssh-keygen -q -t ed25519 -N '' -f "$key"

cat > "$work/setup.service" <<'EOF'
[Unit]
Description=Lumi OS boot test: test account, GDM autologin and SSH (test VM only)
Before=gdm.service display-manager.service
After=systemd-user-sessions.service

[Service]
Type=oneshot
RemainAfterExit=yes
ImportCredential=lumi-test.*
ExecStart=/bin/bash %d/lumi-test.setup
EOF
printf '[Unit]\nWants=lumi-test-setup.service\nAfter=lumi-test-setup.service\n' > "$work/gdm-dropin.conf"
printf '[Unit]\nWants=lumi-test-setup.service\n' > "$work/multi-user-dropin.conf"

smbios=()
cred() { smbios+=(-smbios "type=11,value=io.systemd.credential.binary:$1=$(base64 -w0 < "$2")"); }
cred systemd.extra-unit.lumi-test-setup.service "$work/setup.service"
cred systemd.unit-dropin.gdm.service "$work/gdm-dropin.conf"
cred systemd.unit-dropin.multi-user.target "$work/multi-user-dropin.conf"
cred lumi-test.setup "$here/guest-setup.sh"
cred lumi-test.ssh-key "$key.pub"

# --- Boot ---------------------------------------------------------------------------------------------------------

qemu-img create -q -f qcow2 -F qcow2 -b "$disk" "$work/overlay.qcow2"
cp "$ovmf_vars" "$work/vars.fd"

log "Booting $disk"
qemu-system-x86_64 \
  -name lumi-os-boot-test \
  -machine q35,accel=kvm -cpu host -smp "${VM_CPUS:-4}" -m "${VM_RAM:-8192}" \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$work/vars.fd" \
  -drive file="$work/overlay.qcow2",if=virtio,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:$ssh_port-:22 -device virtio-net-pci,netdev=net0 \
  -device virtio-vga -display none \
  -device qemu-xhci -device usb-tablet \
  -serial file:"$work/serial.log" \
  -monitor unix:"$mon_sock",server,nowait \
  "${smbios[@]}" \
  -daemonize -pidfile "$work/qemu.pid" || {
  fail "VM starts" "qemu-system-x86_64 failed"
  exit 1
}

# Wait for SSH, keeping a screenshot every minute so a stuck boot shows where it stopped.
end=$((SECONDS + boot_timeout))
next_shot=$((SECONDS + 60))
until vm true 2>/dev/null; do
  if ((SECONDS >= end)); then
    shot boot-timeout >/dev/null
    fail "VM boots and answers over SSH" "nothing within ${boot_timeout}s (see screenshots and serial.log)"
    exit 1
  fi
  if ((SECONDS >= next_shot)); then
    shot boot >/dev/null
    next_shot=$((SECONDS + 60))
  fi
  sleep 5
done
pass "VM boots and answers over SSH" "after ${SECONDS}s"

# --- Checks -------------------------------------------------------------------------------------------------------

if wait_for 300 vm 'systemctl is-active --quiet graphical.target'; then
  pass "graphical.target reached"
else
  fail "graphical.target reached" "$(vm 'systemctl is-active graphical.target; systemctl --failed --no-legend' 2>&1 | tr '\n' ' ')"
fi

if v=$(vm 'rpm -q lumi-launcher' 2>&1); then
  pass "lumi-launcher installed" "$v"
else
  fail "lumi-launcher installed" "$v"
fi

if wait_for 300 vm "pgrep -u $user -x gnome-shell >/dev/null"; then
  pass "GNOME session for $user running" "$(vm "loginctl list-sessions --no-legend" | tr -s ' \n' ' ')"
else
  fail "GNOME session for $user running" "no gnome-shell for $user"
fi

if wait_for 180 vm "pgrep -u $user -x lumi >/dev/null"; then
  pass "lumi running after login" "$(vm "pgrep -a -u $user -x lumi" | head -3 | tr '\n' ' ')"
else
  fail "lumi running after login" "no lumi process for $user"
fi

# Test-only session tweak: no screen blanking.
as_user gsettings set org.gnome.desktop.session idle-delay 0 || true

kb_schema=org.gnome.settings-daemon.plugins.media-keys
kb_path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lumi/
keybinding_ok() {
  as_user gsettings get $kb_schema custom-keybindings | grep -qF "$kb_path" || return 1
  kb_command=$(as_user gsettings get "$kb_schema.custom-keybinding:$kb_path" command)
  kb_binding=$(as_user gsettings get "$kb_schema.custom-keybinding:$kb_path" binding)
  [[ -n $kb_command && $kb_command != "''" && $kb_binding == "'<Control>space'" ]]
}
if wait_for 120 keybinding_ok; then
  pass "Lumi GNOME shortcut set" "command=$kb_command binding=$kb_binding"
else
  fail "Lumi GNOME shortcut set" "list=$(as_user gsettings get $kb_schema custom-keybindings 2>&1) command=${kb_command:-?} binding=${kb_binding:-?}"
fi

# Ctrl+Space: GNOME should run Lumi's shortcut command and Lumi's bar should appear.
# GNOME 50 has no D-Bus window list for outside callers (Introspect.GetWindows is denied), so the bar is detected by
# comparing screenshots, and the shortcut firing by gsd-media-keys' "Application launched" line in the user journal.
shortcut_runs() {
  vm "journalctl -b -o cat _UID=\$(id -u $user) | grep -c 'lumi.*launched by gsd-media-keys'" 2>/dev/null || true
}
# Percent of the screen that differs between two screenshots.
changed_percent() {
  [[ -n $1 && -n $2 ]] || { echo 0; return; }
  local changed w h
  changed=$(compare -metric AE -fuzz 10% "$1" "$2" null: 2>&1 | awk '{ printf "%d", $1 }')
  read -r w h < <(identify -format '%w %h' "$2")
  echo $((${changed:-0} * 100 / (w * h)))
}

sleep 20 # let the session settle after login
shot desktop-after-login
# First login lands in the overview with GNOME's "Welcome" dialog on top, which takes the keyboard: close both the
# way a person would.
mon "sendkey esc"
sleep 2
mon "sendkey esc"
sleep 3
shot desktop-after-esc

fired="" opened=""
for attempt in 1 2; do
  runs_before=$(shortcut_runs)
  shot "before-ctrl-space-$attempt"
  before_png=$last_shot
  mon "sendkey ctrl-spc"
  sleep 6
  shot "after-ctrl-space-$attempt"
  after_png=$last_shot
  runs_after=$(shortcut_runs)
  ((${runs_after:-0} > ${runs_before:-0})) && fired="gsd-media-keys ran Lumi's command (press $attempt)"
  pct=$(changed_percent "$before_png" "$after_png")
  log "press $attempt: shortcut runs $runs_before -> $runs_after, screen changed $pct%"
  ((pct >= 2)) && opened="$pct% of the screen changed after the key press (press $attempt)"
  [[ -n $fired && -n $opened ]] && break
  sleep 5
done
if [[ -n $fired ]]; then
  pass "Ctrl+Space runs Lumi's shortcut" "$fired"
else
  fail "Ctrl+Space runs Lumi's shortcut" "no 'launched by gsd-media-keys' for lumi in the user journal after two presses"
fi
if [[ -n $opened ]]; then
  pass "Lumi's bar appears on Ctrl+Space" "$opened"
else
  fail "Lumi's bar appears on Ctrl+Space" "screen unchanged after two presses (see screenshots)"
fi

# --- Logs ---------------------------------------------------------------------------------------------------------

log "Collecting logs"
vm 'journalctl -b --no-pager' > "$out/logs/journal.txt" 2>&1
vm "journalctl -b --no-pager _UID=\$(id -u $user)" > "$out/logs/journal-$user.txt" 2>&1
vm 'systemctl --failed --no-pager; echo; systemctl status lumi-test-setup.service gdm.service --no-pager' \
  > "$out/logs/systemd.txt" 2>&1
vm "cat /etc/os-release; echo; rpm -q lumi-launcher; echo; bootc status 2>/dev/null || rpm-ostree status; echo; \
  loginctl list-sessions; echo; ps -eo user,pid,etime,args --sort=user" > "$out/logs/system.txt" 2>&1
as_user dconf dump / > "$out/logs/dconf-$user.txt" 2>&1
shot final >/dev/null

echo >&2
cat "$results" >&2
if ((failures > 0)); then
  log "$failures check(s) failed"
  exit 1
fi
log "All checks passed"
