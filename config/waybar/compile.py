#!/usr/bin/env python3
import re
import subprocess
import sys
import os

# Get directory of this script
dir_path = os.path.dirname(os.path.realpath(__file__))
themes_dir = os.path.join(dir_path, 'themes')

def get_available_themes():
    if not os.path.exists(themes_dir):
        return []
    themes = []
    for f in sorted(os.listdir(themes_dir)):
        if f.endswith('.scss'):
            themes.append(f[:-5])
    return themes

def print_help(themes):
    print("Waybar Style Compiler & Theme Switcher")
    print("Usage:")
    print("  python3 compile.py [theme]       Compile and apply a specific theme")
    print("  python3 compile.py gui           Open a GUI theme selector (Rofi)")
    print("  python3 compile.py list          List all available themes")
    print("  python3 compile.py reload        Reload Waybar configuration")
    print("  python3 compile.py help | -h     Show this help screen")
    print("\nAvailable themes:")
    for t in themes:
        print(f"  - {t}")
    print()

def run_rofi(themes):
    try:
        theme_list = "\n".join(themes)
        # Custom clean style for rofi menu
        process = subprocess.Popen(
            ['rofi', '-dmenu', '-i', '-p', '󰏘  Theme', '-mesg', 'Select a Waybar theme style'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        stdout, _ = process.communicate(input=theme_list)
        if process.returncode == 0 and stdout.strip():
            return stdout.strip()
    except FileNotFoundError:
        pass
    return None

def run_tui(themes):
    print("\n=== 󰏘  Waybar Theme Selector ===")
    for i, t in enumerate(themes, 1):
        print(f"  [{i}] {t}")
    print("=================================")
    try:
        choice = input(f"Select a theme (1-{len(themes)}): ").strip()
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(themes):
                return themes[idx]
        else:
            # Check if they typed the name directly
            if choice.lower() in [t.lower() for t in themes]:
                for t in themes:
                    if t.lower() == choice.lower():
                        return t
    except (KeyboardInterrupt, EOFError):
        print("\nCancelled.")
    return None

def reload_waybar():
    print("Reloading Waybar...")
    # Send USR2 to waybar
    res = subprocess.run(['pkill', '-USR2', 'waybar'])
    if res.returncode != 0:
        # If it wasn't running, start it
        print("Waybar wasn't running, starting it...")
        subprocess.Popen(['waybar'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def compile_theme(theme_name):
    scss_path = os.path.join(themes_dir, f'{theme_name}.scss')
    css_path = os.path.join(dir_path, 'style.css')

    if not os.path.exists(scss_path):
        print(f"Error: Theme '{theme_name}' not found at {scss_path}")
        sys.exit(1)

    print(f"Compiling theme '{theme_name}'...")
    with open(scss_path, 'r') as f:
        content = f.read()

    # Pre-process GTK variables and functions
    placeholder_content = re.sub(r'@(?!(import|keyframes|define-color|media)\b)(\w+)', r'___GTK___\2', content)
    placeholder_content = placeholder_content.replace('alpha(', '___GTK_FN___alpha(')
    placeholder_content = placeholder_content.replace('mix(', '___GTK_FN___mix(')

    # Compile using sassc
    try:
        process = subprocess.Popen(['sassc', '-s'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=dir_path)
        stdout, stderr = process.communicate(input=placeholder_content)
    except FileNotFoundError:
        print("Error: 'sassc' is not installed. Please install it (e.g. 'sudo pacman -S sassc').")
        sys.exit(1)

    if process.returncode != 0:
        print('Sass Compilation Error:')
        print(stderr)
        sys.exit(1)

    # Post-process: replace placeholders back and fix GTK CSS incompatibilities
    final_css = stdout.replace('___GTK___', '@').replace('___GTK_FN___alpha(', 'alpha(').replace('___GTK_FN___mix(', 'mix(')
    # Remove @charset since GTK CSS does not support it
    final_css = re.sub(r'@charset\s+[^;]+;\s*', '', final_css)
    # Restore @import 'colors.css' format
    final_css = final_css.replace("@import url(colors.css);", "@import 'colors.css';")

    with open(css_path, 'w') as f:
        f.write(final_css)

    print('Compiled successfully!')
    reload_waybar()

def main():
    themes = get_available_themes()
    if not themes:
        print(f"Error: No SCSS themes found in {themes_dir}")
        sys.exit(1)

    if len(sys.argv) < 2:
        # Default fallback to original
        compile_theme('original')
        sys.exit(0)

    arg = sys.argv[1].strip()
    
    # Strip extension/prefixes if they entered the raw filename
    if arg.endswith('.scss'):
        arg = arg[:-5]
    if arg.startswith('style-'):
        arg = arg[6:]

    arg_lower = arg.lower()

    if arg_lower in ['help', '-h', '--help']:
        print_help(themes)
    elif arg_lower == 'list':
        print("Available themes:")
        for t in themes:
            print(f"  - {t}")
    elif arg_lower == 'reload':
        reload_waybar()
    elif arg_lower in ['gui', 'select']:
        selected = run_rofi(themes)
        if not selected:
            # Fallback to TUI
            selected = run_tui(themes)
        if selected:
            compile_theme(selected)
    else:
        # Direct theme name compilation
        # Check matching theme name case-insensitively
        matched = None
        for t in themes:
            if t.lower() == arg_lower:
                matched = t
                break
        
        # Fallback aliases
        if not matched:
            if arg_lower in ['glass', 'liquid-glass']:
                matched = 'glass'
            elif arg_lower in ['original', 'default', 'classic']:
                matched = 'original'

        if matched:
            compile_theme(matched)
        else:
            print(f"Error: Argument '{sys.argv[1]}' not recognized.")
            print_help(themes)
            sys.exit(1)

if __name__ == '__main__':
    main()
