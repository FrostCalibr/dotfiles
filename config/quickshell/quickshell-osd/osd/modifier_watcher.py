import subprocess
import json
import time
import sys

# Sentinel: use this when we can't read state so we don't emit a spurious change.
_UNSET = object()

def get_states(last_num, last_caps):
    """Return (numLock, capsLock) from the main keyboard device.
    Falls back to (last_num, last_caps) on any error so transient
    Hyprland socket hiccups never produce a spurious state change."""
    try:
        out = subprocess.check_output(
            ["hyprctl", "devices", "-j"],
            timeout=1
        )
        data = json.loads(out)
        for kb in data.get("keyboards", []):
            if kb.get("main") is True:
                return kb.get("numLock", last_num), kb.get("capsLock", last_caps)
        # No main device found — keep last known state.
        return last_num, last_caps
    except Exception:
        # Socket busy / timeout / bad JSON — keep last known state.
        return last_num, last_caps


# Bootstrap: run get_states with False defaults only on first call.
last_num, last_caps = get_states(False, False)

print(f"INIT {1 if last_num else 0} {1 if last_caps else 0}")
sys.stdout.flush()

while True:
    time.sleep(0.15)
    num, caps = get_states(last_num, last_caps)
    if num != last_num or caps != last_caps:
        print(f"CHANGE {1 if num else 0} {1 if caps else 0}")
        sys.stdout.flush()
        last_num = num
        last_caps = caps
