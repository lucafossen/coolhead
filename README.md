# coolhead

A **rolling average ThinkPad fan control** that reacts to sustained heat.

Instead of adjusting fan speed on every temperature reading, coolhead maintains a rolling average over the last 30 seconds and only changes the fan when that average crosses a threshold. The result is a fan that stays quiet during brief CPU bursts and only ramps up when the machine is genuinely hot.

## How it works

- Polls CPU package temperature every 10 seconds
- Averages the last 3 readings (30 second window)
- Maps the average to a fan level using a tuned curve with hysteresis
- On shutdown, returns fan control to the firmware

## Presets

Three built-in presets are included:

| Preset        | Fans off until | Max fan at |
|---------------|---------------|------------|
| `quiet`       | 65°C          | 89°C       |
| `balanced`    | 60°C          | 86°C       |
| `performance` | 50°C          | 76°C       |

Fan levels map approximately to: `0`=off, `1`≈10%, `2`≈30%, `3`≈40%, `4`≈50%, `5`≈65%, `7`≈90%.

## Requirements

- **Hardware:** ThinkPad (or compatible Lenovo laptop) with the `thinkpad_acpi` kernel module
- **OS:** Any Linux distribution running systemd with kernel 4.x or newer
- **Python:** 3.6+
- **Text Editor (for managing fan curve presets):** `nano` (default) or any editor set via `$EDITOR`
- `sudo` access

## Install

```bash
git clone https://github.com/lucafossen/coolhead
cd coolhead
bash install.sh
```

The installer will:
1. Check if `thinkfan` is currently running and prompt before proceeding
2. Enable fan control via `thinkpad_acpi`
3. Copy the script and CLI to `/usr/local/bin/`
4. Write default presets and settings to `/etc/coolhead/`
5. Install and start the systemd service

## Uninstall

```bash
bash uninstall.sh
```

Removes all installed files and stops the service. If `thinkfan` is installed, you will be prompted to choose whether fan control should be handed back to `thinkfan` or to the firmware.

## Usage

```bash
coolhead set <preset>          # switch preset and restart the service
coolhead presets               # list all presets (built-in and custom)
coolhead status                # show active preset and service status
```

### Managing presets

`coolhead edit` opens presets in `$EDITOR`, defaulting to `nano` if not set. To use a different editor:

```bash
export EDITOR=vim   # add to ~/.bashrc to make permanent
```

```bash
coolhead new <name>            # create a new preset (copied from balanced)
coolhead edit <name>           # edit a preset in $EDITOR
coolhead delete <name>         # delete a preset
coolhead reset <name>          # reset a built-in preset to factory defaults
coolhead reset --all           # reset all built-in presets to factory defaults
```

When editing a preset, a file like this opens in your editor:

```
# coolhead preset: mypreset
# Columns: fan_level  lower_°C  upper_°C
# Fan levels: 0=off, 2≈30%, 3≈40%, 4≈50%, 5≈65%, 7≈90%
# Save and close to apply. Lines starting with # are ignored.

 0     0    60
 2    58    68
 3    66    75
 4    73    82
 5    80    88
 7    86   999
```

Validation rules:
- `fan_level` must be between 0 and 7
- `lower_°C` must be less than `upper_°C`
- Each row's lower bound must be less than the previous row's upper bound (hysteresis overlap)

### Settings

`poll_interval × window` is the effective sustain time, i.e. how long a temperature must be elevated before the fan responds.

```bash
coolhead config                          # show current settings
coolhead config set poll_interval 15     # seconds between readings
coolhead config set window 4             # number of readings to average
```

## Logs

```bash
journalctl -u coolhead -f
```

Output includes each reading, the rolling average, and any fan level changes:

```
13:42:10 readings=[57, 58, 57]°C  avg=57.3°C  level=0
13:42:20 readings=[58, 57, 61]°C  avg=58.7°C  level=0
13:42:30 readings=[57, 61, 63]°C  avg=60.3°C  level=0
13:42:30 fan -> level 2
```
