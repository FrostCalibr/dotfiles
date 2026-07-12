import os
import re
import sys
import json
import webbrowser
from threading import Timer
from flask import Flask, request, jsonify, render_template, send_from_directory
from dotenv import load_dotenv

# Ensure local imports work correctly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from profile import load_profile, update_profile, save_profile, import_liked_games
from igdb_client import IGDBClient, FIELDS_LIST
from groq_client import GroqClient

DOTENV_PATH = ".env"
load_dotenv(DOTENV_PATH)

app = Flask(__name__, template_folder="templates", static_folder="static")

def is_configured():
    """Checks if all required API keys are configured."""
    # Force reload
    load_dotenv(DOTENV_PATH, override=True)
    return bool(os.getenv("GROQ_API_KEY") and os.getenv("TWITCH_CLIENT_ID") and os.getenv("TWITCH_CLIENT_SECRET"))

def get_clients():
    """Returns instances of clients using current env variables."""
    load_dotenv(DOTENV_PATH, override=True)
    igdb = IGDBClient()
    groq = GroqClient()
    return igdb, groq

def parse_recommendation_blocks(recommendation_text: str, candidates: list) -> list:
    """Parses Groq recommend_games response text block into structured dictionaries."""
    # Split by standard divider first
    blocks = recommendation_text.split("---")
    
    # If LLM didn't output --- properly or merged them, split by GAME:
    if len([b for b in blocks if b.strip()]) <= 1 or any(b.lower().count("game:") > 1 for b in blocks):
        raw_blocks = re.split(r"(?:\s*|🎮\s*|GAME\s*\d*:\s*)?GAME:", recommendation_text, flags=re.IGNORECASE)
        blocks = []
        for rb in raw_blocks[1:]:
            rb_clean = rb.strip()
            if rb_clean:
                blocks.append("GAME: " + rb_clean)
                
    parsed_games = []
    
    for block in blocks:
        block_clean = block.strip()
        if not block_clean:
            continue
            
        # Match Game Name
        game_name = ""
        name_match = re.search(r"GAME:\s*(.*?)(?=\n\s*(?:\s*|📝\s*)?WHY YOU'LL LOVE IT:|\n\s*(?:󰓎\s*|🎯\s*)?BEST FOR:|\n\s*(?:\s*|💻\s*)?COMPATIBILITY:|$)", block_clean, re.IGNORECASE | re.DOTALL)
        if name_match:
            game_name = name_match.group(1).strip()
            game_name = re.sub(r"[\[\]\-\*#]", "", game_name).strip()
        if not game_name:
            continue
            
        # Match Why You'll Love It
        why_love = ""
        why_match = re.search(r"WHY YOU'LL LOVE IT:\s*(.*?)(?=\n\s*(?:󰓎\s*|🎯\s*)?BEST FOR:|\n\s*(?:\s*|💻\s*)?COMPATIBILITY:|$)", block_clean, re.IGNORECASE | re.DOTALL)
        if why_match:
            why_love = why_match.group(1).strip()
            why_love = re.sub(r"[\[\]\-\*#]", "", why_love).strip()
            
        # Match Best For
        best_for = ""
        best_match = re.search(r"BEST FOR:\s*(.*?)(?=\n\s*(?:\s*|💻\s*)?COMPATIBILITY:|$)", block_clean, re.IGNORECASE | re.DOTALL)
        if best_match:
            best_for = best_match.group(1).strip()
            best_for = re.sub(r"[\[\]\-\*#]", "", best_for).strip()
            
        # Match Compatibility
        compat_rating = "PLAYABLE"
        compat_reason = ""
        compat_match = re.search(r"COMPATIBILITY:\s*(.*?)(?=\n\s*---|^\s*---|$)", block_clean, re.IGNORECASE | re.DOTALL)
        if compat_match:
            compat_str = compat_match.group(1).strip()
            rating_match = re.search(r"(EXCELLENT|PLAYABLE|UNPLAYABLE)", compat_str, re.IGNORECASE)
            if rating_match:
                compat_rating = rating_match.group(1).upper()
                reason_part = compat_str[rating_match.end():].strip()
                reason_part = re.sub(r'^[\]\)\-\s\–\—]+', '', reason_part).strip()
                compat_reason = reason_part
            else:
                compat_reason = compat_str
                
        # Match back to candidate to find cover and video trailer ID
        cover_url = ""
        video_id = ""
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
                    
        if matching_game:
            game_name = matching_game.get("name", game_name)
            if "cover" in matching_game:
                raw_url = matching_game["cover"].get("url")
                if raw_url:
                    cover_url = "https:" + raw_url.replace("t_thumb", "t_cover_big")
            if "videos" in matching_game:
                videos = matching_game.get("videos", [])
                if videos:
                    video_id = videos[0].get("video_id")
                    
        parsed_games.append({
            "name": game_name,
            "cover_url": cover_url,
            "video_id": video_id,
            "why_love": why_love,
            "best_for": best_for,
            "compatibility_rating": compat_rating,
            "compatibility_reason": compat_reason
        })
        
    return parsed_games

@app.route("/")
def index():
    """Serves the main dashboard application HTML."""
    return render_template("index.html")

@app.route("/api/status")
def status():
    """Returns configuration status."""
    return jsonify({
        "configured": is_configured()
    })

@app.route("/api/setup", methods=["POST"])
def setup():
    """Accepts credentials, configures .env, and registers keys."""
    data = request.json or {}
    groq_key = data.get("groq_key", "").strip()
    twitch_id = data.get("twitch_id", "").strip()
    twitch_secret = data.get("twitch_secret", "").strip()
    
    if not groq_key or not twitch_id or not twitch_secret:
        return jsonify({"error": "All credential fields are required"}), 400
        
    # Overwrite .env lines
    env_lines = []
    if os.path.exists(DOTENV_PATH):
        with open(DOTENV_PATH, "r", encoding="utf-8") as f:
            env_lines = f.readlines()
            
    keys_to_set = {
        "GROQ_API_KEY": groq_key,
        "TWITCH_CLIENT_ID": twitch_id,
        "TWITCH_CLIENT_SECRET": twitch_secret
    }
    
    new_lines = []
    for line in env_lines:
        if not any(line.startswith(k + "=") for k in keys_to_set):
            new_lines.append(line)
            
    for k, v in keys_to_set.items():
        new_lines.append(f"{k}={v}\n")
        
    with open(DOTENV_PATH, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
        
    # Reload env variables
    load_dotenv(DOTENV_PATH, override=True)
    
    return jsonify({"success": True, "message": "Credentials updated successfully"})

@app.route("/api/profile")
def get_profile():
    """Returns the current user taste profile."""
    profile = load_profile()
    return jsonify(profile)

@app.route("/api/profile/detect_specs")
def detect_specs():
    """Runs local hardware spec detection and returns it."""
    # Import main spec detector
    from main import detect_system_specs
    try:
        detected = detect_system_specs()
        return jsonify(detected)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/profile/specs", methods=["POST"])
def save_specs():
    """Saves system specs to user profile."""
    data = request.json or {}
    profile = load_profile()
    
    profile["system_specs"] = {
        "cpu": data.get("cpu", "").strip(),
        "gpu": data.get("gpu", "").strip(),
        "ram": data.get("ram", "").strip(),
        "storage": data.get("storage", "").strip(),
        "description": data.get("description", "budget PC").strip()
    }
    save_profile(profile)
    return jsonify({"success": True, "profile": profile})

@app.route("/api/import_liked", methods=["POST"])
def import_liked():
    """Cleans names via Groq, loads IGDB details, and saves to profile."""
    if not is_configured():
        return jsonify({"error": "API keys not configured"}), 400
        
    data = request.json or {}
    raw_names = data.get("raw_names", "").strip()
    if not raw_names:
        return jsonify({"error": "No games entered"}), 400
        
    igdb_client, groq_client = get_clients()
    profile = load_profile()
    
    try:
        corrected_names = groq_client.correct_game_spelling(raw_names)
        imported_games = []
        for name in corrected_names:
            results = igdb_client.search_games(name)
            if results:
                best_match = results[0]
                game_meta = {
                    "name": best_match.get("name"),
                    "genres": [g.get("name") for g in best_match.get("genres", []) if g.get("name")],
                    "themes": [t.get("name") for t in best_match.get("themes", []) if t.get("name")]
                }
                imported_games.append(game_meta)
                
        if imported_games:
            import_liked_games(profile, imported_games)
            return jsonify({
                "success": True, 
                "imported_count": len(imported_games),
                "imported_list": [g["name"] for g in imported_games],
                "profile": profile
            })
        else:
            return jsonify({"error": "Could not identify any matching games on IGDB"}), 404
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/recommend", methods=["POST"])
def recommend():
    """Generates game recommendations based on user input and taste profile."""
    if not is_configured():
        return jsonify({"error": "API keys not configured"}), 400
        
    data = request.json or {}
    query = data.get("query", "").strip()
    if not query:
        return jsonify({"error": "Recommendation request details are required"}), 400
        
    igdb_client, groq_client = get_clients()
    profile = load_profile()
    
    try:
        # Extract search parameters
        search_params = groq_client.extract_search_terms(query)
        search_str = search_params.get("search", query)
        genres = search_params.get("genres", [])
        themes = search_params.get("themes", [])
        
        # Query IGDB
        candidates = igdb_client.search_games(search_str, genres, themes)
        if not candidates:
            return jsonify({"error": "No games matching those criteria could be found in the database. Try rephrasing your search."}), 404
            
        # Filter already played games
        played_games_lower = {name.lower().strip() for name in profile.get("played", [])}
        filtered_candidates = [
            game for game in candidates 
            if game.get("name", "").lower().strip() not in played_games_lower
        ]
        
        if not filtered_candidates:
            filtered_candidates = candidates
            
        # Format details
        formatted_candidates_text = format_game_data(filtered_candidates[:8])
        
        # Query Groq recommendations
        recommendation_text = groq_client.recommend_games(query, profile, formatted_candidates_text)
        
        # Parse blocks
        recommendations = parse_recommendation_blocks(recommendation_text, candidates)
        
        return jsonify({
            "success": True,
            "search_query": search_str,
            "filters": {"genres": genres, "themes": themes},
            "recommendations": recommendations
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/discover", methods=["POST"])
def discover_games():
    """Fetches list of games from IGDB to discover, matching filter queries and excluding played games."""
    if not is_configured():
        return jsonify({"error": "API keys not configured"}), 400
        
    data = request.json or {}
    platform = data.get("platform", "").strip()
    brand = data.get("brand", "").strip()
    genre = data.get("genre", "").strip()
    theme = data.get("theme", "").strip()
    
    igdb_client, groq_client = get_clients()
    profile = load_profile()
    
    try:
        # Build query clauses
        conditions = ["rating > 60", "version_parent = null"]
        
        # Exact/Partial platform match
        if platform:
            conditions.append(f'platforms.name ~ *"{platform}"*')
            
        # Publisher/Developer (involved companies) match
        if brand:
            conditions.append(f'involved_companies.company.name ~ *"{brand}"*')
            
        # Genre match
        if genre:
            conditions.append(f'genres.name ~ *"{genre}"*')
            
        # Theme match
        if theme:
            conditions.append(f'themes.name ~ *"{theme}"*')
            
        # If no explicit filters except platform, use user profile preferences as guidance
        if not brand and not genre and not theme:
            liked_genres = profile.get("liked_genres", [])
            liked_themes = profile.get("liked_themes", [])
            
            liked_conds = []
            for g in liked_genres[:3]:
                liked_conds.append(f'genres.name = "{g}"')
            for t in liked_themes[:3]:
                liked_conds.append(f'themes.name = "{t}"')
                
            if liked_conds:
                conditions.append("(" + " | ".join(liked_conds) + ")")
                
        fields_str = ", ".join(FIELDS_LIST)
        where_clause = "where " + " & ".join(conditions) + ";"
        
        # Query up to 40 games sorted by rating desc (popular and highly-rated)
        query_body = f'fields {fields_str}; {where_clause} limit 40; sort rating desc;'
        
        print(f"Discover IGDB Query: {query_body}")
        candidates = igdb_client.query_games(query_body)
        
        # Filter played games
        played_games_lower = {name.lower().strip() for name in profile.get("played", [])}
        filtered_games = []
        for g in candidates:
            g_name = g.get("name", "")
            if g_name.lower().strip() not in played_games_lower:
                cover_url = ""
                if "cover" in g:
                    raw_url = g["cover"].get("url")
                    if raw_url:
                        cover_url = "https:" + raw_url.replace("t_thumb", "t_cover_big")
                        
                video_id = ""
                if "videos" in g:
                    videos = g.get("videos", [])
                    if videos:
                        video_id = videos[0].get("video_id")
                
                platforms = [p.get("name") for p in g.get("platforms", []) if p.get("name")]
                companies = []
                for ic in g.get("involved_companies", []):
                    comp = ic.get("company", {})
                    if comp.get("name"):
                        companies.append(comp.get("name"))
                        
                filtered_games.append({
                    "name": g_name,
                    "cover_url": cover_url,
                    "video_id": video_id,
                    "why_love": g.get("summary", "No summary available."), # Reuse why_love field name for easy mapping
                    "platforms": platforms,
                    "best_for": companies[0] if companies else "Unknown Developer", # Reuse best_for field name for brand/dev tag
                    "rating": g.get("rating"),
                    "genres": [gen.get("name") for gen in g.get("genres", []) if gen.get("name")],
                    "themes": [thm.get("name") for thm in g.get("themes", []) if thm.get("name")]
                })
                
        # Limit to top 15 results for discover
        filtered_games = filtered_games[:15]
        
        # Compute compatibility assessment in a batch call to Groq
        if filtered_games:
            specs = profile.get("system_specs", {})
            try:
                compat_results = groq_client.assess_compatibility_batch(filtered_games, specs)
                compat_map = {item.get("name", "").lower().strip(): item for item in compat_results.get("compatibility", [])}
                
                for fg in filtered_games:
                    key = fg["name"].lower().strip()
                    if key in compat_map:
                        fg["compatibility_rating"] = compat_map[key].get("rating", "PLAYABLE").upper()
                        fg["compatibility_reason"] = compat_map[key].get("reason", "")
                    else:
                        fg["compatibility_rating"] = "PLAYABLE"
                        fg["compatibility_reason"] = "Hardware capability estimated playable."
            except Exception as ex:
                print(f"Batch compatibility estimation error: {ex}")
                for fg in filtered_games:
                    fg["compatibility_rating"] = "PLAYABLE"
                    fg["compatibility_reason"] = "Hardware capability estimated playable."
                    
        return jsonify({
            "success": True,
            "games": filtered_games
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/rate", methods=["POST"])
def rate():
    """Submits liking feedback for a specific game and updates the profile notes."""
    if not is_configured():
        return jsonify({"error": "API keys not configured"}), 400
        
    data = request.json or {}
    game_name = data.get("game_name", "").strip()
    feedback = data.get("feedback", "").strip().lower() # "yes", "no", "skip"
    
    if not game_name or feedback not in ["yes", "no", "skip"]:
        return jsonify({"error": "Game name and feedback (yes/no/skip) are required"}), 400
        
    igdb_client, groq_client = get_clients()
    profile = load_profile()
    
    try:
        # Search IGDB to fetch metadata for accurate genre/theme profile mappings
        genres = []
        themes = []
        
        results = igdb_client.search_games(game_name)
        if results:
            best_match = results[0]
            game_name = best_match.get("name", game_name)
            genres = [g.get("name") for g in best_match.get("genres", []) if g.get("name")]
            themes = [t.get("name") for t in best_match.get("themes", []) if t.get("name")]
            
        game_data = {
            "name": game_name,
            "genres": genres,
            "themes": themes
        }
        
        # Update profile
        notes_regen_needed = update_profile(profile, game_data, feedback)
        
        # Regenerate notes if needed
        notes_updated = False
        if notes_regen_needed:
            new_notes = groq_client.summarize_profile(profile)
            profile["notes"] = new_notes
            save_profile(profile)
            notes_updated = True
            
        return jsonify({
            "success": True,
            "game": game_name,
            "feedback": feedback,
            "notes_updated": notes_updated,
            "profile": profile
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def format_game_data(games: list) -> str:
    """A direct local mirror to format game data for prompt input (centralized)."""
    # Import the main formatter from igdb_client
    from igdb_client import format_game_data as main_formatter
    return main_formatter(games)

def open_browser():
    """Auto-opens default browser to Flask server."""
    webbrowser.open_new("http://127.0.0.1:5000/")

if __name__ == "__main__":
    # Launch browser after 1.5 seconds delay
    Timer(1.5, open_browser).start()
    
    # Run server locally
    app.run(host="127.0.0.1", port=5000, debug=False)
