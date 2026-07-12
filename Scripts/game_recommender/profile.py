import os
import json
import copy

DEFAULT_PROFILE = {
    "played": [],
    "liked": [],
    "disliked": [],
    "liked_genres": [],
    "liked_themes": [],
    "disliked_genres": [],
    "notes": "",
    "interaction_count": 0,
    "system_specs": {
        "cpu": "",
        "gpu": "",
        "ram": "",
        "storage": "",
        "description": ""
    }
}

def load_profile(file_path="user_profile.json") -> dict:
    """Loads the user profile from a JSON file. If it doesn't exist, creates an empty one."""
    if not os.path.exists(file_path):
        default = copy.deepcopy(DEFAULT_PROFILE)
        save_profile(default, file_path)
        return default
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            profile = json.load(f)
            # Ensure all default keys exist (handles nested dicts)
            default = copy.deepcopy(DEFAULT_PROFILE)
            for key, val in default.items():
                if key not in profile:
                    profile[key] = val
                elif isinstance(val, dict):
                    for subkey, subval in val.items():
                        if subkey not in profile[key]:
                            profile[key][subkey] = subval
            return profile
    except (json.JSONDecodeError, OSError):
        # If file is corrupted, return default profile
        return copy.deepcopy(DEFAULT_PROFILE)

def save_profile(profile: dict, file_path="user_profile.json") -> None:
    """Saves the user profile to a JSON file, filtering out internal keys if needed."""
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(profile, f, indent=2, ensure_ascii=False)
    except OSError as e:
        print(f"Error saving user profile: {e}")

def update_profile(profile: dict, game_data: dict, feedback: str, file_path="user_profile.json") -> bool:
    """
    Updates the profile dict and saves it.
    Returns True if notes regeneration is needed (every 5 yes/no interactions).
    """
    game_name = game_data.get("name")
    if not game_name:
        return False

    # Ensure the game is in the played list
    if game_name not in profile["played"]:
        profile["played"].append(game_name)

    feedback = feedback.lower().strip()
    notes_regeneration_needed = False

    if feedback == "yes":
        if game_name not in profile["liked"]:
            profile["liked"].append(game_name)
        
        # Avoid having the game in both liked and disliked
        if game_name in profile["disliked"]:
            profile["disliked"].remove(game_name)

        # Update liked genres and themes
        for genre in game_data.get("genres", []):
            if genre not in profile["liked_genres"]:
                profile["liked_genres"].append(genre)
                
        for theme in game_data.get("themes", []):
            if theme not in profile["liked_themes"]:
                profile["liked_themes"].append(theme)
        
        profile["interaction_count"] += 1
        if profile["interaction_count"] > 0 and profile["interaction_count"] % 5 == 0:
            notes_regeneration_needed = True

    elif feedback == "no":
        if game_name not in profile["disliked"]:
            profile["disliked"].append(game_name)
            
        # Avoid having the game in both liked and disliked
        if game_name in profile["liked"]:
            profile["liked"].remove(game_name)

        # Update disliked genres
        for genre in game_data.get("genres", []):
            if genre not in profile["disliked_genres"]:
                profile["disliked_genres"].append(genre)

        profile["interaction_count"] += 1
        if profile["interaction_count"] > 0 and profile["interaction_count"] % 5 == 0:
            notes_regeneration_needed = True

    save_profile(profile, file_path)
    return notes_regeneration_needed

def import_liked_games(profile: dict, games_list: list, file_path="user_profile.json") -> None:
    """Imports a batch list of games that the user liked, updating genres and themes."""
    for game in games_list:
        game_name = game.get("name")
        if not game_name:
            continue
        if game_name not in profile["played"]:
            profile["played"].append(game_name)
        if game_name not in profile["liked"]:
            profile["liked"].append(game_name)
        if game_name in profile["disliked"]:
            profile["disliked"].remove(game_name)
            
        for genre in game.get("genres", []):
            if genre not in profile["liked_genres"]:
                profile["liked_genres"].append(genre)
        for theme in game.get("themes", []):
            if theme not in profile["liked_themes"]:
                profile["liked_themes"].append(theme)
    save_profile(profile, file_path)
