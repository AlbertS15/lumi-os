#!/usr/bin/env python3
"""Fill .github/release/notes.md for one release and print the result.

The download section depends on whether the ISO fit under GitHub's 2 GiB
asset limit or had to be split into parts, so it is generated here.
"""
import argparse
import pathlib


def gib(n: int) -> str:
    return f"{n / 2**30:.1f}"


def download_single(iso, size, base):
    ru = (
        f"- [`{iso}`]({base}/{iso}) — установщик, {gib(size)} ГБ\n"
        f"- [`SHA256SUMS`]({base}/SHA256SUMS) — контрольная сумма"
    )
    en = (
        f"- [`{iso}`]({base}/{iso}) — the installer, {gib(size)} GB\n"
        f"- [`SHA256SUMS`]({base}/SHA256SUMS) — checksum"
    )
    return ru, en


def download_split(iso, size, parts, base):
    links = "\n".join(f"- [`{p}`]({base}/{p})" for p in parts)
    sums = f"- [`SHA256SUMS`]({base}/SHA256SUMS)"
    unix = f"cat {iso}.part* > {iso}"
    win = f"copy /b {'+'.join(parts)} {iso}"
    ru = f"""GitHub не принимает файлы больше 2 ГБ, поэтому установщик ({gib(size)} ГБ) разрезан на {len(parts)} части. Скачайте **все части** и `SHA256SUMS` в одну папку:

{links}
{sums}

Затем склейте части в один ISO, в этой папке:

- Linux и macOS (Терминал):
  ```sh
  {unix}
  ```
- Windows (командная строка `cmd`, не PowerShell):
  ```bat
  {win}
  ```

Получится `{iso}`, его и записывайте на флешку. Части после проверки можно удалить."""
    en = f"""GitHub does not accept files over 2 GiB, so the installer ({gib(size)} GiB) is split into {len(parts)} parts. Download **all parts** and `SHA256SUMS` into one folder:

{links}
{sums}

Then join the parts into one ISO, in that folder:

- Linux and macOS (Terminal):
  ```sh
  {unix}
  ```
- Windows (Command Prompt `cmd`, not PowerShell):
  ```bat
  {win}
  ```

You get `{iso}`; that is the file to write to the USB stick. The parts can be deleted once it checks out."""
    return ru, en


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--iso", required=True)
    ap.add_argument("--iso-size", required=True, type=int)
    ap.add_argument("--image", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--parts", required=True, help="directory with the release assets")
    a = ap.parse_args()

    base = f"https://github.com/{a.repo}/releases/download/{a.version}"
    parts = sorted(p.name for p in pathlib.Path(a.parts).glob(f"{a.iso}.part*"))
    if parts:
        ru, en = download_split(a.iso, a.iso_size, parts, base)
    else:
        ru, en = download_single(a.iso, a.iso_size, base)

    text = pathlib.Path(a.template).read_text(encoding="utf-8")
    for key, value in {
        "@@VERSION@@": a.version,
        "@@ISO@@": a.iso,
        "@@IMAGE@@": a.image,
        "@@DOWNLOAD_RU@@": ru,
        "@@DOWNLOAD_EN@@": en,
    }.items():
        text = text.replace(key, value)
    print(text, end="")


if __name__ == "__main__":
    main()
