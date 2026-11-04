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

**From scratch:** the ISO is built by the "Build disk images" workflow (Actions → Build disk images → Run workflow) and attached to that run.

**ARM (Apple Silicon Macs in UTM, ARM laptops):** the image is multi-arch (amd64 and arm64), so the same `bootc switch` works on aarch64. For a VM, run "Build disk images" with platform `arm64` (or `both`) and use the `qcow2-arm64` or `anaconda-iso-arm64` artifact.

## How it's built

- `Containerfile` starts from `ghcr.io/ublue-os/silverblue-main:latest` and runs `build_files/build.sh`. Universal Blue builds that image for x86-64 only, so the arm64 image starts from `quay.io/fedora/fedora-silverblue` at the same Fedora version (without Universal Blue's extras such as RPM Fusion codecs).
- `build_files/build.sh` installs Lumi's `.rpm` for the image's CPU (`x86_64` or `aarch64`) from the latest release and applies the files in `system_files/`.
- `system_files/` holds the wallpaper, the GNOME defaults (`zz0-lumi-os.gschema.override`) and Lumi's autostart entry for new accounts.
- `tools/wallpaper.py` draws the wallpaper.
- GitHub Actions rebuilds the image every day, so Fedora updates and new Lumi releases arrive on their own.

Lumi OS is an independent project, not affiliated with Fedora, Red Hat or Universal Blue. Based on the Universal Blue [image template](https://github.com/ublue-os/image-template) (Apache-2.0).
