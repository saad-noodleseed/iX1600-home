# iX1600-home

Scan to Google Drive with a ScanSnap iX1600, without ScanSnap Cloud or vendor software.

```
[iX1600] ─USB─ [Raspberry Pi 4] ── Wi-Fi ──> Google Drive folder
```

Press **Scan** on the scanner. The Pi scans both sides, makes a searchable PDF
(OCR), and uploads it to the Drive folder set by `root_folder_id` in rclone.
If the internet is down, scans wait on the Pi and upload later.

## Prerequisites

- Raspberry Pi OS Lite (64-bit), on Wi-Fi with SSH working
- `rclone config` done with a remote named **`gdrive`**, as your normal user
- Scanner plugged into the Pi by USB, Wi-Fi turned off on the scanner

## Install

```
sudo apt install -y git
git clone https://github.com/saad-noodleseed/ix1600-home.git
cd ix1600-home
sudo ./install.sh
```

Log out and back in, then check that the Pi sees the scanner:

```
sudo systemctl stop scanbd
scanimage -L                # should list a fujitsu device for the iX1600
sudo scanpi-scan            # test scan of what is in the feeder
sudo systemctl start scanbd
```

Then press **Scan** on the scanner.

## Watching and troubleshooting

| What | Command |
| --- | --- |
| Scan log | `tail -f /var/lib/scanpi/scan.log` |
| OCR/upload log | `journalctl -fu scanpi-process` |
| Button detection | `sudo systemctl stop scanbd; sudo scanbd -f -d7` (press Scan, watch output) |
| Jobs waiting / failed | `ls /var/lib/scanpi/{incoming,outbox,failed}` |

If the Scan button does nothing but `scanpi-scan` works, the button isn't being
detected. Run the button-detection command above and share the output.

## Settings

Edit `/etc/scanpi.conf`: destination, subfolders by date, OCR language, colour
mode, resolution, duplex, blank-page skipping.

## Files

| Path in repo | Installed to | Role |
| --- | --- | --- |
| `config/scanbd.conf` | `/etc/scanbd/scanbd.conf` | Maps the Scan button to the script |
| `scripts/scan.script` | `/etc/scanbd/scripts/` | Button hook |
| `scripts/scanpi-scan` | `/usr/local/bin/` | Scans pages into `/var/lib/scanpi/incoming` |
| `scripts/scanpi-process` | `/usr/local/bin/` | OCR, then `rclone move` to Drive |
| `systemd/scanpi-process.*` | `/etc/systemd/system/` | Runs processing on new scans and every 10 min |
| `config/scanpi.conf` | `/etc/scanpi.conf` | Your settings (not overwritten on reinstall) |
