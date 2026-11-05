**Русский** · [English](#english)

## Lumi OS @@VERSION@@

Lumi OS — это обычный Linux с рабочим столом GNOME (Fedora Silverblue от Universal Blue), в котором уже стоит [Lumi](https://github.com/AlbertS15/Lumi): строка с нейросетью по Ctrl+Пробел. Lumi запускается при входе, а при первом входе показывает приветствие, где одной кнопкой ставится нейросеть, работающая без интернета. Обновления приходят целым образом и откатываются из меню загрузки.

> **Ранняя версия.** Пробуйте на отдельном компьютере, на втором диске или в виртуальной машине. Установщик стирает диск, который вы выберете, поэтому сначала сохраните свои файлы.
>
> **Только x86-64** (обычные компьютеры с Intel или AMD). Компьютеры на ARM, включая Mac с чипами Apple, пока не поддерживаются.

### Скачать

@@DOWNLOAD_RU@@

### Проверить файл

В `SHA256SUMS` первой строкой записана контрольная сумма целого ISO. Посчитайте сумму своего файла и сравните:

- Linux: `sha256sum -c SHA256SUMS --ignore-missing`
- macOS: `shasum -a 256 -c SHA256SUMS --ignore-missing`
- Windows (PowerShell): `Get-FileHash @@ISO@@ -Algorithm SHA256`

Если суммы не совпали, скачайте файл ещё раз.

### Записать на флешку

Нужна флешка на 8 ГБ или больше, всё на ней будет стёрто.

- **[Fedora Media Writer](https://fedoraproject.org/workstation/download)** (Windows, macOS, Linux): «Выбрать .iso файл» → выберите `@@ISO@@` → выберите флешку → «Записать».
- **[balenaEtcher](https://etcher.balena.io)** (Windows, macOS, Linux): «Flash from file» → `@@ISO@@` → «Select target» → флешка → «Flash!».

Затем загрузите компьютер с флешки (обычно F12, F11, F8 или Esc при включении), выберите диск и дождитесь конца установки. После перезагрузки система предложит создать пользователя, а при первом входе откроется приветствие Lumi.

Уже стоит Fedora Silverblue, Bluefin, Bazzite или Aurora? ISO не нужен: `sudo bootc switch ghcr.io/alberts15/lumi-os:latest` и перезагрузка.

### О проекте

Lumi OS — независимый проект одного автора. Он не связан с Fedora, Red Hat или Universal Blue и не одобрен ими. Собрано из образа `@@IMAGE@@`.

---

<a id="english"></a>

## Lumi OS @@VERSION@@ (English)

Lumi OS is a regular Linux with the GNOME desktop (Fedora Silverblue from Universal Blue) that ships with [Lumi](https://github.com/AlbertS15/Lumi), the AI bar on Ctrl+Space, already installed. Lumi starts at login; the first login opens its welcome window, where one button installs an AI model that works offline. Updates arrive as a whole new image and can be rolled back from the boot menu.

> **Early version.** Try it on a spare computer, a second disk or a virtual machine. The installer erases the disk you choose, so back up your files first.
>
> **x86-64 only** (regular Intel or AMD computers). ARM computers, including Apple silicon Macs, are not supported yet.

### Download

@@DOWNLOAD_EN@@

### Check the file

The first line of `SHA256SUMS` is the checksum of the whole ISO. Compute the checksum of your file and compare:

- Linux: `sha256sum -c SHA256SUMS --ignore-missing`
- macOS: `shasum -a 256 -c SHA256SUMS --ignore-missing`
- Windows (PowerShell): `Get-FileHash @@ISO@@ -Algorithm SHA256`

If they don't match, download the file again.

### Write it to a USB stick

You need a USB stick of 8 GB or more; everything on it will be erased.

- **[Fedora Media Writer](https://fedoraproject.org/workstation/download)** (Windows, macOS, Linux): "Select .iso file" → pick `@@ISO@@` → pick the USB stick → "Write".
- **[balenaEtcher](https://etcher.balena.io)** (Windows, macOS, Linux): "Flash from file" → `@@ISO@@` → "Select target" → the USB stick → "Flash!".

Then boot the computer from the USB stick (usually F12, F11, F8 or Esc at power-on), choose a disk and wait for the install to finish. After the reboot the system asks you to create a user, and the first login opens Lumi's welcome window.

Already on Fedora Silverblue, Bluefin, Bazzite or Aurora? You don't need the ISO: `sudo bootc switch ghcr.io/alberts15/lumi-os:latest`, then reboot.

### About

Lumi OS is an independent one-person project. It is not affiliated with or endorsed by Fedora, Red Hat or Universal Blue. Built from the image `@@IMAGE@@`.
