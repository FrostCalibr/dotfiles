import subprocess
import json
import time
import sys

def get_states():
    try:
        out = subprocess.check_output(["hyprctl", "devices", "-j"])
        data = json.loads(out)
        keyboards = data.get("keyboards", [])
        numlock = False
        capslock = False
        for kb in keyboards:
            if kb.get("main") == True:
                numlock = kb.get("numLock", False)
                capslock = kb.get("capsLock", False)
                break
        return numlock, capslock
    except Exception:
        return False, False

last_num, last_caps = get_states()

# Output initial state
print(f"INIT {1 if last_num else 0} {1 if last_caps else 0}")
sys.stdout.flush()

while True:
    time.sleep(0.15)
    num, caps = get_states()
    if num != last_num or caps != last_caps:
        print(f"CHANGE {1 if num else 0} {1 if caps else 0}")
        sys.stdout.flush()
        last_num = num
        last_caps = caps
