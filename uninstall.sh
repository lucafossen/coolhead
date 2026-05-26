#!/usr/bin/env bash
set -e

echo "==> Uninstalling coolhead..."

# Collect all decisions before making any changes
fan_handoff="firmware"
if systemctl cat thinkfan &>/dev/null; then
    echo ""
    echo "  thinkfan is installed. What should take over fan control?"
    echo "  1) Firmware (auto)"
    echo "  2) thinkfan"
    echo ""
    read -rp "  Choice [1/2]: " choice
    [[ "$choice" == "2" ]] && fan_handoff="thinkfan"
fi

# Stop and disable service
if systemctl is-active --quiet coolhead; then
    sudo systemctl disable --now coolhead
fi

# Remove files
sudo rm -f /etc/systemd/system/coolhead.service
sudo rm -f /usr/local/bin/coolhead.py
sudo rm -f /usr/local/bin/coolhead
sudo rm -f /etc/modprobe.d/thinkpad_acpi.conf
sudo rm -rf /etc/coolhead
sudo systemctl daemon-reload

# Apply chosen fan handoff
if [[ "$fan_handoff" == "thinkfan" ]]; then
    sudo systemctl enable --now thinkfan
    echo "==> Done. Fan control handed to thinkfan."
else
    echo "level auto" | sudo tee /proc/acpi/ibm/fan > /dev/null
    echo "==> Done. Fan control returned to firmware (auto)."
fi
