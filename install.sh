#!/bin/bash
# Set up the Pi: Scan button -> PDF -> Google Drive.
# Run from the repo folder as the user who ran "rclone config":  sudo ./install.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ]; then
    echo "Run as your normal user with sudo:  sudo ./install.sh"
    exit 1
fi
cd "$(dirname "$0")"
USER_NAME=$SUDO_USER

echo "== Installing packages"
apt-get update
apt-get install -y sane-utils scanbd img2pdf rclone

echo "== Checking rclone remote"
if ! sudo -u "$USER_NAME" rclone listremotes | grep -qx 'gdrive:'; then
    echo "No rclone remote named 'gdrive' for $USER_NAME. Run 'rclone config' first."
    exit 1
fi

echo "== Spool folders and permissions"
usermod -aG scanner "$USER_NAME"
usermod -aG scanner saned
install -d -o root -g scanner -m 2775 /var/lib/scanpi \
    /var/lib/scanpi/incoming /var/lib/scanpi/outbox /var/lib/scanpi/failed

echo "== Config and scripts"
[ -f /etc/scanpi.conf ] || install -m 644 config/scanpi.conf /etc/scanpi.conf
install -m 755 scripts/scanpi-scan scripts/scanpi-process /usr/local/bin/
install -d /etc/scanbd/scripts
install -m 755 scripts/scan.script /etc/scanbd/scripts/scan.script
[ -f /etc/scanbd/scanbd.conf.orig ] || cp /etc/scanbd/scanbd.conf /etc/scanbd/scanbd.conf.orig
install -m 644 config/scanbd.conf /etc/scanbd/scanbd.conf

# scanbd uses its own SANE config folder; make sure the fujitsu backend is in it.
if [ -d /etc/scanbd/sane.d ]; then
    grep -qx fujitsu /etc/scanbd/sane.d/dll.conf 2>/dev/null \
        || echo fujitsu >> /etc/scanbd/sane.d/dll.conf
    [ -f /etc/scanbd/sane.d/fujitsu.conf ] \
        || cp /etc/sane.d/fujitsu.conf /etc/scanbd/sane.d/
fi

echo "== systemd units"
sed "s/@USER@/$USER_NAME/" systemd/scanpi-process.service \
    > /etc/systemd/system/scanpi-process.service
install -m 644 systemd/scanpi-process.path systemd/scanpi-process.timer systemd/scanbd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now scanpi-process.path scanpi-process.timer
systemctl enable scanbd
systemctl restart scanbd

echo
echo "Done. Log out and back in (for the 'scanner' group), then press Scan."
echo "Watch it work:  tail -f /var/lib/scanpi/scan.log   and   journalctl -fu scanpi-process"
