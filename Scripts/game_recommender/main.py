import os
import re
import sys
import requests
import shutil
import subprocess
import webbrowser
from dotenv import load_dotenv

# Ensure local imports work correctly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from profile import load_profile, update_profile, save_profile
from igdb_client import IGDBClient, format_game_data
from groq_client import GroqClient

# ANSI Terminal Colors for Rich Aesthetics
C_PURPLE = "\033[95m"
C_CYAN = "\033[96m"
C_GREEN = "\033[92m"
C_YELLOW = "\033[93m"
C_RED = "\033[91m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_RESET = "\033[0m"

DOTENV_PATH = ".env"

def print_welcome():
    """Prints a beautiful, rich welcome message."""
    print(f"\n{C_PURPLE}{C_BOLD}======================================================================{C_RESET}")
    print(f"   {C_CYAN}{C_BOLD}AI-POWERED GAME RECOMMENDATION SYSTEM v2{C_RESET}")
    print(f"{C_PURPLE}{C_BOLD}======================================================================{C_RESET}")
    print(f" Describe your ideal game experience in natural language. For example:")
    print(f" {C_DIM}\"something dark and atmospheric where you feel lost\" or \"cozy building games\"{C_RESET}")
    print(f"\n We'll query real-time IGDB game details, cross-reference them with")
    print(f" your taste profile and PC hardware specs, and suggest up to 5 games.")
    print(f"{C_PURPLE}{C_BOLD}----------------------------------------------------------------------{C_RESET}\n")

def get_required_input(prompt_text: str) -> str:
    """Helper to ensure user doesn't submit empty fields for API keys."""
    while True:
        val = input(prompt_text).strip()
        if val:
            return val
        print(f"{C_RED}Error: This field cannot be empty. Please enter a value.{C_RESET}")

def run_credentials_wizard():
    """Prompts for keys if they are missing from env and writes to .env file."""
    load_dotenv(DOTENV_PATH)
    
    groq_key = os.getenv("GROQ_API_KEY")
    twitch_id = os.getenv("TWITCH_CLIENT_ID")
    twitch_secret = os.getenv("TWITCH_CLIENT_SECRET")
    
    if not groq_key or not twitch_id or not twitch_secret:
        print(f"{C_YELLOW}{C_BOLD}┌────────────────────────────────────────────────────────────┐{C_RESET}")
        print(f"{C_YELLOW}{C_BOLD}│               API KEY CONFIGURATION WIZARD                 │{C_RESET}")
        print(f"{C_YELLOW}{C_BOLD}└────────────────────────────────────────────────────────────┘{C_RESET}")
        print("Some required environment variables are missing. Let's configure them now.\n")
        
        if not groq_key:
            groq_key = get_required_input(f" {C_BOLD}Enter GROQ_API_KEY{C_RESET} (from console.groq.com): ")
        if not twitch_id:
            twitch_id = get_required_input(f" {C_BOLD}Enter TWITCH_CLIENT_ID{C_RESET} (from dev.twitch.tv/console): ")
        if not twitch_secret:
            twitch_secret = get_required_input(f" {C_BOLD}Enter TWITCH_CLIENT_SECRET{C_RESET} (from dev.twitch.tv/console): ")

        # Write or update the .env file
        env_lines = []
        if os.path.exists(DOTENV_PATH):
            with open(DOTENV_PATH, "r", encoding="utf-8") as f:
                env_lines = f.readlines()
        
        # Filter out existing lines for these keys
        keys_to_set = {"GROQ_API_KEY": groq_key, "TWITCH_CLIENT_ID": twitch_id, "TWITCH_CLIENT_SECRET": twitch_secret}
        new_lines = []
        for line in env_lines:
            if not any(line.startswith(k + "=") for k in keys_to_set):
                new_lines.append(line)
        
        for k, v in keys_to_set.items():
            new_lines.append(f"{k}={v}\n")
            
        with open(DOTENV_PATH, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
            
        print(f"\n{C_GREEN} API credentials successfully saved to {os.path.abspath(DOTENV_PATH)}!{C_RESET}")
        # Reload dotenv
        load_dotenv(DOTENV_PATH, override=True)

def parse_multiple_game_names(recommendation: str) -> list:
    """Extracts all game names from the multi-game recommendation block."""
    matches = re.findall(r"GAME:\s*(.*)", recommendation, re.IGNORECASE)
    cleaned = []
    for name in matches:
        name_clean = name.strip()
        # Clean markdown wrappers or trailing headers if any
        name_clean = re.sub(r"[\[\]\-\*#]", "", name_clean).strip()
        if name_clean and name_clean not in cleaned:
            cleaned.append(name_clean)
    return cleaned

def parse_recommended_game_name_from_block(block: str) -> str:
    """Parses the game name from a single recommendation block."""
    match = re.search(r"GAME:\s*(.*)", block, re.IGNORECASE)
    if match:
        name_clean = match.group(1).strip()
        name_clean = re.sub(r"[\[\]\-\*#]", "", name_clean).strip()
        return name_clean
    return ""

def download_image(url: str, dest_path: str) -> bool:
    """Downloads an image from a URL and saves it locally."""
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            with open(dest_path, "wb") as f:
                f.write(response.content)
            return True
    except Exception:
        pass
    return False

def display_game_cover(game_name: str, candidates: list):
    """Finds the cover URL for the game in candidates, downloads it, and renders it in Kitty."""
    matching_game = None
    for c in candidates:
        if c.get("name", "").lower().strip() == game_name.lower().strip():
            matching_game = c
            break
    if not matching_game:
        for c in candidates:
            c_name_lower = c.get("name", "").lower().strip()
            r_name_lower = game_name.lower().strip()
            if c_name_lower in r_name_lower or r_name_lower in c_name_lower:
                matching_game = c
                break
                
    if matching_game and "cover" in matching_game:
        cover_url = matching_game["cover"].get("url")
        if cover_url:
            full_url = "https:" + cover_url.replace("t_thumb", "t_cover_big")
            temp_path = "temp_cover.jpg"
            
            if download_image(full_url, temp_path):
                if shutil.which("kitty"):
                    try:
                        print("  ", end="")
                        subprocess.run(["kitty", "+kitten", "icat", "--align", "left", temp_path], stderr=subprocess.DEVNULL)
                        print()
                    except Exception:
                        pass
                else:
                    print(f"  {C_RED}Kitty terminal icat utility is not available in PATH.{C_RESET}")
                try:
                    os.remove(temp_path)
                except Exception:
                    pass
        else:
            print(f"  {C_YELLOW}No cover art URL available for this game.{C_RESET}")
    else:
        print(f"  {C_YELLOW}No cover details found in the database.{C_RESET}")

def play_game_video(game_name: str, candidates: list):
    """Finds YouTube video ID, plays natively in mpv or opens default browser."""
    matching_game = None
    for c in candidates:
        if c.get("name", "").lower().strip() == game_name.lower().strip():
            matching_game = c
            break
    if not matching_game:
        for c in candidates:
            c_name_lower = c.get("name", "").lower().strip()
            r_name_lower = game_name.lower().strip()
            if c_name_lower in r_name_lower or r_name_lower in c_name_lower:
                matching_game = c
                break
                
    video_id = None
    if matching_game and "videos" in matching_game:
        videos = matching_game.get("videos", [])
        if videos:
            video_id = videos[0].get("video_id")
            
    if not video_id:
        print(f"  {C_RED}No video trailer was found for this game in the database.{C_RESET}")
        return
        
    youtube_url = f"https://www.youtube.com/watch?v={video_id}"
    
    # Try playing natively with mpv --vo=kitty if mpv is in PATH
    if shutil.which("mpv"):
        print(f"  Playing trailer natively in Kitty using mpv...")
        print(f"  {C_DIM}(Press 'q' inside the video window to quit at any time){C_RESET}\n")
        try:
            subprocess.run(["mpv", "--vo=kitty", youtube_url])
        except Exception as e:
            print(f"  {C_RED}Failed to play using mpv: {e}{C_RESET}")
            webbrowser.open(youtube_url)
            print(f"  Opened trailer in default web browser: {youtube_url}")
    else:
        webbrowser.open(youtube_url)
        print(f"  mpv is not installed. Opened trailer in your default web browser:\n  {C_BOLD}{youtube_url}{C_RESET}")

def run_media_viewer(rec_game_names: list, candidates: list):
    """Launches a fullscreen-like alternate screen buffer to browse game media."""
    # Switch to alternate screen buffer
    print("\033[?1049h", end="", flush=True)
    
    try:
        while True:
            os.system("clear")
            print(f"{C_PURPLE}{C_BOLD}┌────────────────────────────────────────────────────────────┐{C_RESET}")
            print(f"{C_PURPLE}{C_BOLD}│             RECOMMENDED GAMES MEDIA VIEWER                 │{C_RESET}")
            print(f"{C_PURPLE}{C_BOLD}└────────────────────────────────────────────────────────────┘{C_RESET}\n")
            print("Select a game to view its images or play its trailer:\n")
            
            for idx, name in enumerate(rec_game_names, 1):
                print(f"  [{idx}] {C_BOLD}{name}{C_RESET}")
            print(f"\n  [exit] Return to recommendations list\n")
            
            choice = input(f"{C_BOLD}Select game index > {C_RESET}").strip().lower()
            if choice == "exit":
                break
                
            if choice.isdigit():
                idx = int(choice)
                if 1 <= idx <= len(rec_game_names):
                    game_name = rec_game_names[idx - 1]
                    while True:
                        os.system("clear")
                        print(f"  {C_CYAN}{C_BOLD}Media Menu: {game_name}{C_RESET}")
                        print(f"{C_DIM}------------------------------------------------------------{C_RESET}\n")
                        print(f"  [1]  View Cover Art (Kitty terminal image rendering)")
                        print(f"  [2]  Play Video Trailer (Plays in mpv --vo=kitty or browser)")
                        print(f"  [3]  Back to list\n")
                        
                        sub_choice = input(f"{C_BOLD}Select option > {C_RESET}").strip()
                        if sub_choice == "3":
                            break
                        elif sub_choice == "1":
                            os.system("clear")
                            print(f"  {C_CYAN}{C_BOLD}Cover Art: {game_name}{C_RESET}\n")
                            display_game_cover(game_name, candidates)
                            input(f"\n{C_DIM}Press Enter to return to menu...{C_RESET}")
                        elif sub_choice == "2":
                            os.system("clear")
                            print(f"  {C_CYAN}{C_BOLD}Video Trailer: {game_name}{C_RESET}\n")
                            play_game_video(game_name, candidates)
                            input(f"\n{C_DIM}Press Enter to return to menu...{C_RESET}")
    finally:
        # Exit alternate screen buffer, restoring normal console state
        print("\033[?1049l", end="", flush=True)

def detect_system_specs() -> dict:
    """Detects CPU, GPU, RAM, and Storage automatically on Linux systems."""
    cpu = "Unknown CPU"
    try:
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if "model name" in line:
                    cpu = line.split(":", 1)[1].strip()
                    break
    except Exception:
        import platform
        cpu = platform.processor() or "Unknown CPU"

    ram = "Unknown RAM"
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if "MemTotal" in line:
                    kb = int(line.split()[1])
                    gb = round(kb / (1024 * 1024), 1)
                    ram = f"{gb} GB"
                    break
    except Exception:
        pass

    gpu = "Unknown GPU"
    try:
        import subprocess
        out = subprocess.check_output("lspci", shell=True, text=True)
        gpu_lines = []
        for line in out.splitlines():
            if any(x in line.lower() for x in ["vga compatible controller", "3d controller", "display controller"]):
                cleaned_line = re.sub(r'^[0-9a-fA-F:\.]+\s*(?:VGA compatible controller|3D controller|Display controller):\s*', '', line, flags=re.IGNORECASE)
                gpu_lines.append(cleaned_line.strip())
        if gpu_lines:
            gpu = " / ".join(gpu_lines)
    except Exception:
        pass

    storage = "Unknown Storage"
    try:
        import shutil
        total, used, free = shutil.disk_usage("/")
        total_gb = round(total / (1024**3), 1)
        free_gb = round(free / (1024**3), 1)
        storage = f"{total_gb} GB total ({free_gb} GB free)"
    except Exception:
        pass

    return {
        "cpu": cpu,
        "gpu": gpu,
        "ram": ram,
        "storage": storage
    }

def check_or_prompt_system_specs(profile: dict):
    """Checks if system specifications are present in user profile, otherwise prompts/detects."""
    specs = profile.setdefault("system_specs", {"cpu": "", "gpu": "", "ram": "", "storage": "", "description": ""})
    
    # Ensure all keys exist
    if "storage" not in specs:
        specs["storage"] = ""

    if not specs.get("description") and not specs.get("cpu") and not specs.get("gpu"):
        print(f"{C_CYAN}{C_BOLD}┌────────────────────────────────────────────────────────────┐{C_RESET}")
        print(f"{C_CYAN}{C_BOLD}│             PC HARDWARE CONFIGURATION WIZARD               │{C_RESET}")
        print(f"{C_CYAN}{C_BOLD}└────────────────────────────────────────────────────────────┘{C_RESET}")
        print("Gathering your hardware specifications automatically...\n")
        
        detected = detect_system_specs()
        print(f"  {C_BOLD}Detected CPU:{C_RESET} {detected['cpu']}")
        print(f" 󰢹 {C_BOLD}Detected GPU:{C_RESET} {detected['gpu']}")
        print(f"  {C_BOLD}Detected RAM:{C_RESET} {detected['ram']}")
        print(f"  {C_BOLD}Detected Storage:{C_RESET} {detected['storage']}")
        
        print(f"\n{C_CYAN}{C_BOLD}Would you like to use these detected specifications?{C_RESET} (yes/no)")
        use_detected = input(f"{C_BOLD}> {C_RESET}").strip().lower()
        while use_detected not in ["yes", "no"]:
            use_detected = input(f"Please enter 'yes' or 'no': ").strip().lower()
            
        if use_detected == "yes":
            specs["cpu"] = detected["cpu"]
            specs["gpu"] = detected["gpu"]
            specs["ram"] = detected["ram"]
            specs["storage"] = detected["storage"]
            
            # Suggest a general description based on detected RAM
            try:
                ram_gb = float(detected["ram"].split()[0])
            except Exception:
                ram_gb = 8.0
                
            default_desc = "budget PC" if ram_gb <= 8.0 else "gaming PC"
            desc = input(f" {C_BOLD}Enter general PC class{C_RESET} [default: '{default_desc}']: ").strip()
            specs["description"] = desc if desc else default_desc
        else:
            print("\nPlease enter your specifications manually:")
            specs["cpu"] = input(f" {C_BOLD}Enter CPU{C_RESET}: ").strip()
            specs["gpu"] = input(f"󰢹 {C_BOLD}Enter GPU{C_RESET}: ").strip()
            specs["ram"] = input(f" {C_BOLD}Enter RAM{C_RESET}: ").strip()
            specs["storage"] = input(f" {C_BOLD}Enter Storage{C_RESET} (e.g. 500 GB SSD): ").strip()
            specs["description"] = get_required_input(f" {C_BOLD}Enter general PC class{C_RESET}: ")
            
        profile["system_specs"] = specs
        save_profile(profile)
        print(f"\n{C_GREEN} System specifications saved to profile!{C_RESET}\n")

def check_or_prompt_liked_games_import(profile: dict, groq_client: GroqClient, igdb_client: IGDBClient):
    """Offers to import liked games to populate the profile on first run."""
    if not profile.get("liked"):
        print(f"{C_CYAN}{C_BOLD}Would you like to import some of your favorite games to initialize your taste?{C_RESET} (yes/no)")
        choice = input(f"{C_BOLD}> {C_RESET}").strip().lower()
        while choice not in ["yes", "no"]:
            choice = input(f"Please enter 'yes' or 'no': ").strip().lower()
            
        if choice == "yes":
            print(f"\n Enter a list of games you've liked (comma-separated).")
            print(f"{C_DIM}Feel free to describe them or make spelling errors! E.g. 'wticher 3, hoolow knight, portals 2'{C_RESET}")
            raw_input = input(f"{C_BOLD}> {C_RESET}").strip()
            if raw_input:
                print(f"\n{C_DIM} Correcting spelling and recognizing games...{C_RESET}")
                corrected_names = groq_client.correct_game_spelling(raw_input)
                print(f" {C_GREEN}└ Recognized games: {corrected_names}{C_RESET}")
                
                print(f"{C_DIM} Retrieving game metadata from IGDB...{C_RESET}")
                imported_games = []
                for name in corrected_names:
                    try:
                        results = igdb_client.search_games(name)
                        if results:
                            best_match = results[0]
                            game_meta = {
                                "name": best_match.get("name"),
                                "genres": [g.get("name") for g in best_match.get("genres", []) if g.get("name")],
                                "themes": [t.get("name") for t in best_match.get("themes", []) if t.get("name")]
                            }
                            imported_games.append(game_meta)
                            print(f"   {C_GREEN} Loaded: {game_meta['name']}{C_RESET}")
                    except Exception as e:
                        print(f"   {C_RED} Failed loading {name}: {e}{C_RESET}")
                        
                if imported_games:
                    from profile import import_liked_games
                    import_liked_games(profile, imported_games)
                    print(f"\n{C_GREEN} Successfully imported {len(imported_games)} games to your profile!{C_RESET}\n")
                else:
                    print(f"{C_RED}Could not match any games on IGDB. Profile remains unchanged.{C_RESET}\n")

def main():
    # Make sure env is set up
    run_credentials_wizard()
    
    # Initialize Clients
    try:
        igdb_client = IGDBClient()
        groq_client = GroqClient()
    except Exception as e:
        print(f"{C_RED}Failed to initialize clients: {e}{C_RESET}")
        sys.exit(1)
        
    # Load User Profile
    profile = load_profile()
    
    print_welcome()
    
    # Run setup wizards if profile lacks information
    check_or_prompt_system_specs(profile)
    check_or_prompt_liked_games_import(profile, groq_client, igdb_client)
    
    while True:
        # Step 1: Get user input
        print(f"{C_CYAN}{C_BOLD}What kind of game are you looking for?{C_RESET}")
        user_input = input(f"{C_BOLD}> {C_RESET}").strip()
        
        if not user_input:
            print(f"{C_RED}Please describe a game style so we can help you!{C_RESET}\n")
            continue
            
        print(f"\n{C_DIM} Analyzing your request and extracting search parameters...{C_RESET}")
        
        # Step 2: Extract search terms using Groq
        try:
            search_params = groq_client.extract_search_terms(user_input)
        except Exception as e:
            print(f"{C_RED}Error extracting search terms from Groq: {e}{C_RESET}\n")
            continue
            
        search_str = search_params.get("search", user_input)
        genres = search_params.get("genres", [])
        themes = search_params.get("themes", [])
        
        print(f" {C_GREEN} Search query: \"{search_str}\"{C_RESET}")
        if genres or themes:
            print(f" {C_GREEN} Extracted filters: Genres={genres}, Themes={themes}{C_RESET}")
            
        print(f"{C_DIM} Searching IGDB game database...{C_RESET}")
        
        # Step 3: Query IGDB
        try:
            candidates = igdb_client.search_games(search_str, genres, themes)
        except Exception as e:
            print(f"{C_RED}Error querying IGDB API: {e}{C_RESET}\n")
            continue
            
        if not candidates:
            print(f"{C_RED}IGDB returned no results for your query. Please try rephrasing or describing a different style.{C_RESET}\n")
            continue
            
        # Filter out already played games before prompting the recommender to keep recommendations fresh
        played_games_lower = {name.lower().strip() for name in profile.get("played", [])}
        filtered_candidates = [
            game for game in candidates 
            if game.get("name", "").lower().strip() not in played_games_lower
        ]
        
        if not filtered_candidates:
            # If all found candidates have been played, keep them so the recommender can choose or we don't crash
            filtered_candidates = candidates
            
        # Format candidate game details (truncating summaries is handled inside format_game_data)
        # Limit to first 8 candidates
        formatted_candidates_text = format_game_data(filtered_candidates[:8])
        
        print(f"{C_DIM} Generating personalized recommendations using Groq LLM...{C_RESET}")
        
        # Step 4: Build prompt & query Groq for Recommendations
        try:
            recommendation = groq_client.recommend_games(user_input, profile, formatted_candidates_text)
        except Exception as e:
            print(f"{C_RED}Error generating recommendations: {e}{C_RESET}\n")
            continue
            
        # Step 5: Display recommendations sequentially with spacious layout
        print(f"\n{C_PURPLE}{C_BOLD}======================= RECOMMENDATIONS ======================={C_RESET}\n")
        
        game_blocks = recommendation.split("---")
        rec_game_names = []
        rec_index = 1
        
        for block in game_blocks:
            block_clean = block.strip()
            if not block_clean:
                continue
                
            game_name = parse_recommended_game_name_from_block(block_clean)
            if not game_name:
                print(block_clean)
                print(f"\n{C_DIM}---------------------------------------------------------------{C_RESET}\n")
                continue
                
            rec_game_names.append(game_name)
            
            # Print beautiful, spaced game header
            print(f"  {C_CYAN}{C_BOLD}[{rec_index}] GAME: {game_name}{C_RESET}\n")
            
            # Strip out the first line (the raw "GAME:" line) to avoid print duplication
            lines = block_clean.splitlines()
            rest_lines = []
            for line in lines:
                if not re.match(r"(?:🎮|\s*)?GAME:", line, re.IGNORECASE):
                    rest_lines.append(line)
            
            rest_text = "\n".join(rest_lines).strip()
            
            # Indent properties block for clean hierarchical look
            indented_lines = []
            for line in rest_text.splitlines():
                if line.strip():
                    indented_lines.append("   " + line)
                else:
                    indented_lines.append("")
                    
            print("\n".join(indented_lines))
            print(f"\n{C_DIM}---------------------------------------------------------------{C_RESET}\n")
            rec_index += 1
            
        print(f"{C_PURPLE}{C_BOLD}==============================================================={C_RESET}\n")
        
        if not rec_game_names:
            print(f"{C_YELLOW}Could not parse recommended game titles from LLM output. Skipping rating step.{C_RESET}\n")
            trigger_notes_summary = False
        else:
            # Loop to allow user to view media or provide feedback
            while True:
                print(f"{C_CYAN}Select an action:{C_RESET}")
                print(f"  • Type {C_BOLD}'media'{C_RESET} to launch the Media Console (images & video trailers)")
                print(f"  • Enter indices of games you {C_GREEN}{C_BOLD}liked{C_RESET} (comma-separated, e.g. '1, 3', or 'skip' to finish)")
                
                liked_input = input(f"\n{C_BOLD}> {C_RESET}").strip().lower()
                
                if liked_input == "media":
                    run_media_viewer(rec_game_names, candidates)
                    continue
                    
                # Otherwise, it's a rating feedback or skip
                liked_indices = []
                disliked_indices = []
                
                if liked_input != "skip" and liked_input != "":
                    try:
                        liked_indices = [int(x.strip()) for x in liked_input.split(",") if x.strip().isdigit()]
                    except Exception:
                        pass
                        
                if liked_input != "skip":
                    disliked_input = input(f"Enter indices of games you {C_RED}{C_BOLD}disliked{C_RESET} (comma-separated, e.g. '2'): ").strip().lower()
                    if disliked_input != "":
                        try:
                            disliked_indices = [int(x.strip()) for x in disliked_input.split(",") if x.strip().isdigit()]
                        except Exception:
                            pass
            
                trigger_notes_summary = False
                
                # Now update profile for each game
                for idx, name in enumerate(rec_game_names, 1):
                    # Match back to retrieve genres and themes
                    matching_game = None
                    for c in candidates:
                        if c.get("name", "").lower().strip() == name.lower().strip():
                            matching_game = c
                            break
                    if not matching_game:
                        for c in candidates:
                            c_name_lower = c.get("name", "").lower().strip()
                            r_name_lower = name.lower().strip()
                            if c_name_lower in r_name_lower or r_name_lower in c_name_lower:
                                matching_game = c
                                break
                                
                    # Construct game data for profile update
                    game_data = {
                        "name": matching_game.get("name") if matching_game else name,
                        "genres": [g.get("name") for g in matching_game.get("genres", []) if g.get("name")] if matching_game else [],
                        "themes": [t.get("name") for t in matching_game.get("themes", []) if t.get("name")] if matching_game else []
                    }
                    
                    if idx in liked_indices:
                        feedback = "yes"
                    elif idx in disliked_indices:
                        feedback = "no"
                    else:
                        feedback = "skip"
                        
                    notes_regen_needed = update_profile(profile, game_data, feedback)
                    if notes_regen_needed:
                        trigger_notes_summary = True
                
                # Periodic notes summarizer (every 5 yes/no interactions)
                if trigger_notes_summary:
                    print(f"\n{C_DIM} Updating your taste profile notes...{C_RESET}")
                    try:
                        new_notes = groq_client.summarize_profile(profile)
                        profile["notes"] = new_notes
                        # Save to file
                        save_profile(profile)
                        print(f" {C_GREEN} Updated Notes: \"{new_notes}\"{C_RESET}")
                    except Exception as e:
                        print(f"{C_RED}Warning: Failed to update taste profile notes: {e}{C_RESET}")
                
                break
                
        # Ask to loop
        print(f"\n{C_CYAN}Want another recommendation?{C_RESET} ({C_GREEN}yes{C_RESET}/{C_RED}no{C_RESET})")
        again = input(f"{C_BOLD}> {C_RESET}").strip().lower()
        while again not in ["yes", "no"]:
            print(f"{C_RED}Invalid input. Please enter 'yes' or 'no'.{C_RESET}")
            again = input(f"{C_BOLD}> {C_RESET}").strip().lower()
            
        if again == "no":
            print(f"\n {C_GREEN}{C_BOLD}Thanks for using the Game Recommender. Have fun gaming!{C_RESET}\n")
            break
        print(f"\n{C_PURPLE}{C_BOLD}----------------------------------------------------------------------{C_RESET}\n")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n {C_GREEN}Session cancelled. Goodbye!{C_RESET}\n")
        sys.exit(0)
