#!/usr/bin/env bash
# Measures Lumi OS images: their size, then how fast a qcow2 made from each boots in QEMU/KVM.
#
#   sudo tools/boot-bench.sh <output dir> <boots> <label=image> [<label=image> ...]
#
# Needs root (podman, bootc-image-builder, /dev/kvm), qemu-system-x86_64 and OVMF.
# Several images are measured in ONE run on the same machine and their boots are interleaved
# (a, b, a, b, ...), so host speed and noise hit all of them alike. Separate CI runners differ
# by up to 2x, which would drown the differences being measured.
# Boot 1 is the first boot (one-time setup); boots 2..N are what a user sees every day.

set -euo pipefail

out=$(realpath -m "$1")
boots=$2
shift 2
labels=()
declare -A images
for pair in "$@"; do
  labels+=("${pair%%=*}")
  images[${pair%%=*}]=${pair#*=}
done
bib=${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}
work=$(mktemp -d -p "${BENCH_TMP:-/var/tmp}")
mkdir -p "$out"

log() { echo "::group::$*"; }
end() { echo "::endgroup::"; }

# A copy of the image with a reporter: once systemd says the boot is finished, it prints
# systemd-analyze to the serial port and powers the VM off. It is a timer + a Type=exec
# service, so it is not part of the boot transaction and does not hold up what it measures.
cat > "$work/lumi-bench-report" <<'SH'
#!/bin/bash
export SYSTEMD_COLORS=0
until systemd-analyze >/dev/null 2>&1; do sleep 1; done
{
  echo "===BENCH-BEGIN==="
  echo "---analyze"; systemd-analyze
  echo "---blame"; systemd-analyze blame --no-pager
  echo "---critical-chain"; systemd-analyze critical-chain graphical.target --no-pager
  echo "---failed"; systemctl list-units --failed --no-legend --no-pager
  echo "===BENCH-END==="
} > /run/lumi-bench-report.txt 2>&1
cat /run/lumi-bench-report.txt > /dev/ttyS0
sync
systemctl poweroff
SH
printf '[Service]\nType=exec\nExecStart=/usr/libexec/lumi-bench-report\n' > "$work/lumi-bench-report.service"
printf '[Timer]\nOnStartupSec=20\n[Install]\nWantedBy=timers.target\n' > "$work/lumi-bench-report.timer"
cat > "$work/Containerfile" <<'EOF'
ARG IMAGE
FROM ${IMAGE}
COPY --chmod=0755 lumi-bench-report /usr/libexec/
COPY lumi-bench-report.service lumi-bench-report.timer /usr/lib/systemd/system/
RUN systemctl enable lumi-bench-report.timer
EOF
cat > "$work/config.toml" <<'EOF'
[[customizations.filesystem]]
mountpoint = "/"
minsize = "20 GiB"
EOF

prepare() {
  local label=$1 image=$2 o w
  o=$out/$label
  w=$work/$label
  mkdir -p "$o" "$w/output"

  log "Image size: $label"
  podman image inspect --format '{{.Size}}' "$image" > "$o/image-bytes.txt"
  podman run --rm --entrypoint /bin/bash "$image" -c '
    echo "rpm_count $(rpm -qa | wc -l)"
    echo "usr_bytes $(du -sxb /usr | cut -f1)"
  ' > "$o/image-stats.txt"
  podman run --rm --entrypoint /bin/bash "$image" -c \
    "rpm -qa --qf '%{SIZE}\t%{NAME}\n' | sort -n" > "$o/rpms-by-size.txt"
  podman run --rm --entrypoint /bin/bash "$image" -c \
    'systemctl list-unit-files --state=enabled --no-legend --no-pager' > "$o/enabled-units.txt" || true
  cat "$o/image-bytes.txt" "$o/image-stats.txt"
  end

  log "Build qcow2: $label"
  podman build --build-arg IMAGE="$image" -t "localhost/lumi-bench:$label" -f "$work/Containerfile" "$work"
  podman run --rm --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$work/config.toml:/config.toml:ro" \
    -v "$w/output:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$bib" --type qcow2 --rootfs btrfs --use-librepo=True "localhost/lumi-bench:$label"
  du -b "$w/output/qcow2/disk.qcow2" | cut -f1 > "$o/qcow2-bytes.txt"
  cp /usr/share/OVMF/OVMF_VARS_4M.fd "$w/vars.fd"
  # The image is no longer needed; free the disk for the next one.
  podman rmi -f "localhost/lumi-bench:$label" >/dev/null || true
  end
}

for label in "${labels[@]}"; do prepare "$label" "${images[$label]}"; done

# --- Boots: interleaved across the images ----------------------------------------------------------
for n in $(seq 1 "$boots"); do
  for label in "${labels[@]}"; do
    o=$out/$label
    w=$work/$label
    log "Boot $n: $label"
    serial=$o/serial-$n.log
    timeout 20m qemu-system-x86_64 -enable-kvm -cpu host -machine q35 -smp 4 -m 8G \
      -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
      -drive if=pflash,format=raw,file="$w/vars.fd" \
      -drive file="$w/output/qcow2/disk.qcow2",if=virtio,format=qcow2 \
      -nic user,model=virtio-net-pci \
      -display none -vga virtio -serial file:"$serial" || true
    report=$(tr -d '\r' < "$serial" | sed -n '/===BENCH-BEGIN===/,/===BENCH-END===/p')
    if [[ -z $report ]]; then
      echo "Boot $n ($label): no report on the serial port" | tee -a "$o/errors.txt"
      tail -c 4000 "$serial" || true
      exit 1
    fi
    section() { sed -n "/^---$1\$/,/^---/p" <<<"$report" | sed -e '1d' -e '/^---/d' -e '/^===/d'; }
    section analyze > "$o/boot-$n-analyze.txt"
    section blame > "$o/boot-$n-blame.txt"
    section critical-chain > "$o/boot-$n-critical-chain.txt"
    section failed > "$o/boot-$n-failed.txt"
    cat "$o/boot-$n-analyze.txt"
    head -25 "$o/boot-$n-blame.txt"
    cat "$o/boot-$n-critical-chain.txt" "$o/boot-$n-failed.txt"
    end
  done
done

# --- Summary ------------------------------------------------------------------------------------
# "Startup finished in 1.2s (kernel) + 3.4s (initrd) + 5.6s (userspace) = 10.2s"
# "graphical.target reached after 5.5s in userspace."
to_s() {  # systemd time span ("1min 2.345s", "812ms") -> seconds
  awk '{ t=0; for (i=1;i<=NF;i++) { v=$i;
    if (v ~ /min$/) { sub(/min$/,"",v); t+=v*60 }
    else if (v ~ /ms$/) { sub(/ms$/,"",v); t+=v/1000 }
    else if (v ~ /s$/) { sub(/s$/,"",v); t+=v } } printf "%.3f\n", t }'
}
for label in "${labels[@]}"; do
  o=$out/$label
  {
    echo "boot,kernel_s,initrd_s,userspace_s,total_s,graphical_target_s"
    for n in $(seq 1 "$boots"); do
      line=$(grep -m1 '^Startup finished' "$o/boot-$n-analyze.txt")
      part() { grep -o "[0-9][^+=]*($1)" <<<"$line" | sed "s/ *($1)//" | to_s; }
      total=$(sed 's/.*= //' <<<"$line" | to_s)
      gt=$(grep -o 'graphical.target reached after .* in userspace' "$o/boot-$n-analyze.txt" |
        sed -e 's/graphical.target reached after //' -e 's/ in userspace//' | to_s)
      echo "$n,$(part kernel),$(part initrd),$(part userspace),$total,$gt"
    done
  } > "$o/summary.csv"
  echo "== $label"; cat "$o/summary.csv"
done
rm -rf "$work"
