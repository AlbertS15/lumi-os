# Lumi OS

Fedora Silverblue from [Universal Blue](https://universal-blue.org) with [Lumi](https://github.com/AlbertS15/Lumi), the AI bar on one key, built in.

Обычный Linux с GNOME, в котором Lumi уже стоит: открывается по Ctrl+Пробел, запускается при входе, а при первом входе показывает приветствие, где одной кнопкой ставится нейросеть без интернета.

## What's inside

- Lumi from its latest release, started at login; the first login opens its welcome window.
- `plocate` with a daily index, so Lumi finds files by name.
- The ghost wallpaper, dark theme with a teal accent, Lumi first in the dash.
- Everything else is Fedora Silverblue as Universal Blue ships it: updates arrive as a whole new image and can be rolled back.

## Try it

**From a Fedora Atomic system** (Silverblue, Bluefin, Bazzite, Aurora):

```bash
sudo bootc switch ghcr.io/alberts15/lumi-os:latest
systemctl reboot
```

Going back: `sudo bootc switch` to the image you had, or pick the previous entry in the boot menu.

**From scratch:** download the installer ISO from [Releases](https://github.com/AlbertS15/lumi-os/releases/latest) (no GitHub account needed) and write it to a USB stick with [Fedora Media Writer](https://fedoraproject.org/workstation/download) or [balenaEtcher](https://etcher.balena.io). GitHub limits release files to 2 GiB, so a bigger ISO comes in parts; the release notes show how to join them and check the checksum. The release ISO is x86-64 only for now, and this is an early version: the installer erases the disk you pick.

New releases come from the "Release ISO" workflow: push a `v*` tag, or Actions → Release ISO → Run workflow with a version. It builds the ISO, attaches it with `SHA256SUMS` to a draft release, and the draft is published by hand.

**ARM (Apple Silicon Macs in UTM, ARM laptops):** the image is multi-arch (amd64 and arm64), so the same `bootc switch` works on aarch64. For a VM, run "Build disk images" (Actions → Build disk images → Run workflow) with platform `arm64` (or `both`) and use the `qcow2-arm64` or `anaconda-iso-arm64` artifact.

### On a Mac with Apple silicon (UTM)

Lumi OS can't be installed next to macOS on an Apple silicon Mac (Linux runs on that hardware only through Asahi Linux, and only on M1/M2), but it runs well in a virtual machine with Apple's hardware acceleration. [UTM](https://mac.getutm.app) is the easiest way:

1. Install UTM: download it from [mac.getutm.app](https://mac.getutm.app) (free) or run `brew install --cask utm`.
2. Get the disk: open [Build disk images](https://github.com/AlbertS15/lumi-os/actions/workflows/build-disk.yml), pick the latest successful run built with platform `arm64` or `both`, download the `qcow2-arm64` artifact (about 3 GB, needs a GitHub sign-in) and unzip it. The file you need is `qcow2/disk.qcow2`.
3. In UTM: **Create a New Virtual Machine → Virtualize → Linux**. Leave the boot ISO empty, give it 8 GB of memory and 4 or more CPU cores, accept any disk size, and save.
4. Select the new VM → **Edit → Drives**: delete the empty drive UTM created, then **New → Import** and pick `disk.qcow2` (interface VirtIO). Save.
5. Start it. The first boot opens GNOME's setup, where you create your account; third-party repositories are optional.

The same disk was tested with plain QEMU on an M5 Pro (`qemu-system-aarch64 -machine virt -accel hvf -cpu host` with the edk2 aarch64 firmware and `virtio-gpu-pci`). The UTM steps above follow UTM's usual disk import; if something doesn't work, please open an [issue](https://github.com/AlbertS15/lumi-os/issues).

## How it's built

- `Containerfile` starts from `ghcr.io/ublue-os/silverblue-main:latest` and runs `build_files/build.sh`. Universal Blue builds that image for x86-64 only, so the arm64 image starts from `quay.io/fedora/fedora-silverblue` at the same Fedora version (without Universal Blue's extras such as RPM Fusion codecs).
- `build_files/build.sh` installs Lumi's `.rpm` for the image's CPU from the latest release (`x86_64`) or the newest release that has one, pre-releases included (`aarch64`, until a stable Lumi release ships it) and applies the files in `system_files/`.
- `system_files/` holds the wallpaper, the GNOME defaults (`zz0-lumi-os.gschema.override`) and Lumi's autostart entry for new accounts.
- `tools/wallpaper.py` draws the wallpaper; `tools/branding.py` draws the boot splash frames and the logos (About, first setup, login screen) from the same ghost sprite.
- GitHub Actions rebuilds the image every day, so Fedora updates and new Lumi releases arrive on their own.

Lumi OS is an independent project, not affiliated with Fedora, Red Hat or Universal Blue. Based on the Universal Blue [image template](https://github.com/ublue-os/image-template) (Apache-2.0).
