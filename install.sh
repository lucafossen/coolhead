#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for thinkfan before touching anything
if systemctl is-active --quiet thinkfan; then
    echo ""
    echo "  thinkfan is currently running."
    echo "  Continuing will disable it in favour of coolhead."
    echo ""
    read -rp "  Proceed? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "==> Aborted."
        exit 1
    fi
fi

echo "==> Installing coolhead..."

# Enable thinkpad_acpi fan control
echo 'options thinkpad_acpi fan_control=1' | sudo tee /etc/modprobe.d/thinkpad_acpi.conf > /dev/null
if sudo modprobe -r thinkpad_acpi 2>/dev/null; then
    sudo modprobe thinkpad_acpi fan_control=1
    echo "==> fan_control=1 enabled."
else
    echo ""
    echo "  Warning: could not reload thinkpad_acpi (module may be in use)."
    echo "  fan_control=1 is saved and will apply on next reboot."
    echo "  To apply now without rebooting, run:"
    echo "    sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi fan_control=1"
    echo ""
fi

# Copy script and CLI
sudo cp "$SCRIPT_DIR/coolhead.py" /usr/local/bin/coolhead.py
sudo cp "$SCRIPT_DIR/coolhead" /usr/local/bin/coolhead
sudo chmod +x /usr/local/bin/coolhead.py /usr/local/bin/coolhead

# Create config directory
sudo mkdir -p /etc/coolhead

# Write default presets (skip if already exists to preserve user edits)
if [ ! -f /etc/coolhead/presets.json ]; then
    sudo python3 - <<'EOF'
import json
presets = {
    "quiet":       [[0,0,65],[2,63,72],[3,70,78],[4,76,84],[5,82,90],[7,88,999]],
    "balanced":    [[0,0,60],[2,58,68],[3,66,75],[4,73,82],[5,80,88],[7,86,999]],
    "performance": [[0,0,50],[2,48,58],[3,56,65],[4,63,72],[5,70,78],[7,76,999]],
}
with open('/etc/coolhead/presets.json', 'w') as f:
    json.dump(presets, f, indent=2)
EOF
    echo "==> Default presets written."
fi

# Write default settings (skip if already exists)
if [ ! -f /etc/coolhead/settings.json ]; then
    echo '{"poll_interval": 10, "window": 3}' | sudo tee /etc/coolhead/settings.json > /dev/null
    echo "==> Default settings written."
fi

# Write default active preset (skip if already exists)
if [ ! -f /etc/coolhead/coolhead.conf ]; then
    echo "balanced" | sudo tee /etc/coolhead/coolhead.conf > /dev/null
fi

# Install service
sudo cp "$SCRIPT_DIR/coolhead.service" /etc/systemd/system/coolhead.service

# Disable thinkfan now that we're committed
if systemctl is-active --quiet thinkfan; then
    sudo systemctl disable --now thinkfan 2>/dev/null || true
    echo "==> thinkfan disabled."
fi

# Enable and start coolhead
sudo systemctl daemon-reload
sudo systemctl enable --now coolhead

echo "==> Done. Status:"
systemctl status coolhead --no-pager
