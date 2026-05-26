#!/usr/bin/env python3
import json
import time
import signal
import sys
import logging
from pathlib import Path
from collections import deque

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    datefmt="%H:%M:%S",
)

FAN            = "/proc/acpi/ibm/fan"
CONFIG_FILE    = "/etc/coolhead/coolhead.conf"
PRESETS_FILE   = "/etc/coolhead/presets.json"
SETTINGS_FILE  = "/etc/coolhead/settings.json"
DEFAULT_PRESET = "balanced"

DEFAULT_PRESETS = {
    "quiet": [
        [0,  0,  65],
        [2, 63,  72],
        [3, 70,  78],
        [4, 76,  84],
        [5, 82,  90],
        [7, 88, 999],
    ],
    "balanced": [
        [0,  0,  60],
        [2, 58,  68],
        [3, 66,  75],
        [4, 73,  82],
        [5, 80,  88],
        [7, 86, 999],
    ],
    "performance": [
        [0,  0,  50],
        [2, 48,  58],
        [3, 56,  65],
        [4, 63,  72],
        [5, 70,  78],
        [7, 76, 999],
    ],
}

DEFAULT_SETTINGS = {
    "poll_interval": 10,
    "window": 3,
}


def load_settings():
    try:
        with open(SETTINGS_FILE) as f:
            return {**DEFAULT_SETTINGS, **json.load(f)}
    except (OSError, json.JSONDecodeError) as e:
        logging.warning(f"Could not load {SETTINGS_FILE}: {e}, using defaults")
        return DEFAULT_SETTINGS.copy()


def load_preset():
    name = DEFAULT_PRESET
    try:
        name = Path(CONFIG_FILE).read_text().strip()
    except OSError:
        pass

    try:
        with open(PRESETS_FILE) as f:
            presets = json.load(f)
        if name in presets:
            return name, [tuple(row) for row in presets[name]]
        logging.warning(f"Preset '{name}' not found in {PRESETS_FILE}, falling back to '{DEFAULT_PRESET}'")
    except (OSError, json.JSONDecodeError) as e:
        logging.warning(f"Could not load {PRESETS_FILE}: {e}, using built-in defaults")

    if name in DEFAULT_PRESETS:
        return name, [tuple(row) for row in DEFAULT_PRESETS[name]]
    return DEFAULT_PRESET, [tuple(row) for row in DEFAULT_PRESETS[DEFAULT_PRESET]]


def find_sensor():
    for hwmon in sorted(Path("/sys/class/hwmon").iterdir()):
        try:
            if (hwmon / "name").read_text().strip() == "coretemp":
                sensor = hwmon / "temp1_input"
                if sensor.exists():
                    return sensor
        except OSError:
            continue
    raise RuntimeError("coretemp sensor not found")


def read_temp(sensor):
    try:
        return int(sensor.read_text().strip()) // 1000
    except OSError as e:
        logging.error(f"failed to read sensor: {e}")
        return None


def set_fan(level):
    try:
        Path(FAN).write_text(f"level {level}\n")
        logging.info(f"fan -> level {level}")
    except OSError as e:
        logging.error(f"failed to set fan level {level}: {e}")


def next_idx(avg, idx, curve):
    _, lower, upper = curve[idx]
    if avg >= upper and idx < len(curve) - 1:
        return idx + 1
    if avg < lower and idx > 0:
        return idx - 1
    return idx


def shutdown(sig, frame):
    set_fan("auto")
    sys.exit(0)


signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)

settings = load_settings()
poll_interval = settings["poll_interval"]
window = settings["window"]

preset_name, curve = load_preset()
logging.info(f"starting with preset '{preset_name}' (poll={poll_interval}s, window={window})")

sensor = find_sensor()
readings = deque(maxlen=window)
idx = 0
set_fan(curve[idx][0])

while True:
    temp = read_temp(sensor)
    if temp is not None:
        readings.append(temp)
    if readings:
        avg = sum(readings) / len(readings)
        logging.info(f"readings={list(readings)}°C  avg={avg:.1f}°C  level={curve[idx][0]}")
        new_idx = next_idx(avg, idx, curve)
        if new_idx != idx:
            idx = new_idx
            set_fan(curve[idx][0])
    time.sleep(poll_interval)
