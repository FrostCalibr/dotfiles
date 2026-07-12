#!/usr/bin/env python3
import os
import re
import sys
import subprocess

BINDS_FILE = os.path.expanduser("~/.config/hypr/modules/binds.conf")

if not os.path.exists(BINDS_FILE):
    print(f"Error: binds file not found at {BINDS_FILE}")
    sys.exit(1)

# Helper to clean up modifiers
def format_mods(mods, main_mod="SUPER"):
    mods = mods.strip()
    if not mods:
        return ""
    # Replace variables
    mods = mods.replace("$mainMod", main_mod)
    # Replace whitespace with +
    mods = "+".join(m.strip() for m in re.split(r'\s+', mods) if m.strip())
    return mods

def parse_binds():
    categories = []
    current_category = "General"
    
    with open(BINDS_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            # Category comment
            if line.startswith("#"):
                comment = line.lstrip("#").strip()
                # Ignore empty comments or disabled binds
                if comment and not comment.startswith("bind"):
                    current_category = comment
                continue
            
            # Bind definition
            if line.startswith("bind"):
                parts = line.split("=", 1)
                if len(parts) < 2:
                    continue
                bind_args = parts[1].strip()
                subparts = [p.strip() for p in bind_args.split(",")]
                if len(subparts) < 3:
                    continue
                
                mods = subparts[0]
                key = subparts[1]
                dispatcher = subparts[2]
                args = ",".join(subparts[3:]) if len(subparts) > 3 else ""
                
                # Format mods and key
                mods_str = format_mods(mods)
                key_str = key.strip()
                shortcut = f"{mods_str} + {key_str}" if mods_str else key_str
                
                action = f"{dispatcher} {args}".strip()
                if dispatcher == "exec":
                    action = args.strip()
                    # Clean up local script path
                    action = re.sub(r"^~/\.config/hypr/scripts/", "", action)
                    action = re.sub(r"^~/\.config/rofi/launchers/emoji/launcher\.sh", "rofi-emoji", action)
                    action = re.sub(r"^~/\.config/rofi/launchers/type-1/launcher\.sh", "rofi-launcher", action)
                    action = re.sub(r"^~/\.config/rofi/powermenu/type-2/powermenu\.sh", "rofi-powermenu", action)
                
                categories.append({
                    "shortcut": shortcut,
                    "action": action,
                    "category": current_category,
                    "raw_line": line
                })
    return categories

def main():
    binds = parse_binds()
    if not binds:
        print("No binds found.")
        sys.exit(0)
        
    # Calculate widths for column formatting
    max_shortcut = max(len(b["shortcut"]) for b in binds)
    max_action = max(len(b["action"]) for b in binds)
    
    # Format options for Rofi
    options = []
    for b in binds:
        shortcut_col = b["shortcut"].ljust(max_shortcut)
        action_col = b["action"].ljust(max_action)
        line_str = f"󰌌  {shortcut_col}   󰘳  {action_col}   󰓹  [{b['category']}]"
        options.append(line_str)
        
    # Show Rofi menu
    options_input = "\n".join(options)
    rofi_cmd = [
        "rofi", "-dmenu", "-i", 
        "-p", "Keybindings", 
        "-theme", os.path.expanduser("~/.config/rofi/launchers/type-1/style-5.rasi")
    ]
    
    try:
        proc = subprocess.Popen(rofi_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        selected, _ = proc.communicate(input=options_input)
        
        if not selected:
            sys.exit(0)
            
        selected = selected.strip()
        if selected in options:
            selected_index = options.index(selected)
            selected_bind = binds[selected_index]
            
            raw_line = selected_bind["raw_line"]
            # Parse command for exec
            if "exec," in raw_line:
                cmd = raw_line.split("exec,")[1].strip()
                # Resolve variables like $terminal, $fileManager
                cmd = cmd.replace("$terminal", "kitty").replace("$fileManager", "nemo")
                # Run command in background
                subprocess.Popen(cmd, shell=True)
            else:
                # For non-exec dispatchers, call hyprctl dispatch
                parts = raw_line.split("=", 1)
                if len(parts) >= 2:
                    bind_args = parts[1].strip()
                    subparts = [p.strip() for p in bind_args.split(",")]
                    if len(subparts) >= 3:
                        dispatcher = subparts[2]
                        args = ",".join(subparts[3:]) if len(subparts) > 3 else ""
                        dispatch_cmd = f"hyprctl dispatch {dispatcher} {args}"
                        subprocess.Popen(dispatch_cmd, shell=True)
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
