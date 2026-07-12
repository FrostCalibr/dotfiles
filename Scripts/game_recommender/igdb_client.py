import os
import time
import json
import requests
from dotenv import load_dotenv

# Load env variables
load_dotenv()

IGDB_GAMES_URL = "https://api.igdb.com/v4/games"
TWITCH_TOKEN_URL = "https://id.twitch.tv/oauth2/token"
TOKEN_CACHE_FILE = ".token_cache.json"

FIELDS_LIST = [
    "name",
    "summary",
    "genres.name",
    "themes.name",
    "platforms.name",
    "game_modes.name",
    "player_perspectives.name",
    "rating",
    "first_release_date",
    "involved_companies.company.name",
    "cover.url",
    "videos.video_id"
]

class IGDBClient:
    def __init__(self, client_id=None, client_secret=None):
        self.client_id = client_id or os.getenv("TWITCH_CLIENT_ID")
        self.client_secret = client_secret or os.getenv("TWITCH_CLIENT_SECRET")
        self.access_token = None
        self.token_expiry = 0
        self._last_request_time = 0

    def _load_cached_token(self):
        """Loads cached token from file if valid."""
        if os.path.exists(TOKEN_CACHE_FILE):
            try:
                with open(TOKEN_CACHE_FILE, "r") as f:
                    cache = json.load(f)
                    # Add buffer of 60 seconds
                    if cache.get("expires_at", 0) > time.time() + 60:
                        self.access_token = cache.get("access_token")
                        self.token_expiry = cache.get("expires_at")
                        return True
            except (json.JSONDecodeError, OSError):
                pass
        return False

    def _save_cached_token(self, token, expires_in):
        """Saves the token to a local JSON file."""
        expires_at = time.time() + expires_in
        cache = {
            "access_token": token,
            "expires_at": expires_at
        }
        try:
            with open(TOKEN_CACHE_FILE, "w") as f:
                json.dump(cache, f)
        except OSError as e:
            print(f"Warning: Could not cache token to file: {e}")

    def get_access_token(self, force_refresh=False):
        """Retrieves Twitch OAuth access token."""
        if not force_refresh and self._load_cached_token():
            return self.access_token

        if not self.client_id or not self.client_secret:
            raise ValueError("Twitch Client ID or Client Secret not configured.")

        params = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "grant_type": "client_credentials"
        }
        
        response = requests.post(TWITCH_TOKEN_URL, params=params)
        if response.status_code != 200:
            raise Exception(f"Failed to obtain Twitch OAuth token: {response.text}")
            
        data = response.json()
        self.access_token = data["access_token"]
        # expires_in is typically 50-60 days (in seconds)
        expires_in = data.get("expires_in", 3600)
        self.token_expiry = time.time() + expires_in
        
        self._save_cached_token(self.access_token, expires_in)
        return self.access_token

    def _rate_limit(self):
        """Maintains rate limiting to 4 requests/second (approx 250ms gap)."""
        now = time.time()
        elapsed = now - self._last_request_time
        if elapsed < 0.26:
            time.sleep(0.26 - elapsed)
        self._last_request_time = time.time()

    def query_games(self, query_body: str) -> list:
        """Executes a raw APICalypse query against IGDB."""
        self._rate_limit()
        token = self.get_access_token()
        
        headers = {
            "Client-ID": self.client_id,
            "Authorization": f"Bearer {token}",
            "Content-Type": "text/plain"
        }
        
        response = requests.post(IGDB_GAMES_URL, headers=headers, data=query_body)
        
        # Handle 401 token expiry gracefully
        if response.status_code == 401:
            print("Access token expired or unauthorized. Refreshing token...")
            token = self.get_access_token(force_refresh=True)
            headers["Authorization"] = f"Bearer {token}"
            response = requests.post(IGDB_GAMES_URL, headers=headers, data=query_body)
            
        if response.status_code != 200:
            # Let's raise or return empty with error log
            print(f"IGDB API request failed with status {response.status_code}: {response.text}")
            response.raise_for_status()
            
        return response.json()

    def search_games(self, search_string: str, genres: list = None, themes: list = None) -> list:
        """
        Searches for games using three layers of fallback:
        1. Search string + genre/theme filters + rating > 60
        2. Fallback: Search string with no rating filter and no genre/theme filters
        3. Fallback: Genre/theme filters only, no search string, rating > 60, sorted by rating
        """
        fields_str = ", ".join(FIELDS_LIST)
        
        # Build first query (with filters and rating > 60)
        conditions = ["rating > 60"]
        
        genre_theme_conditions = []
        if genres:
            for g in genres:
                g_esc = g.replace('"', '\\"')
                genre_theme_conditions.append(f'genres.name = "{g_esc}"')
        if themes:
            for t in themes:
                t_esc = t.replace('"', '\\"')
                genre_theme_conditions.append(f'themes.name = "{t_esc}"')
                
        if genre_theme_conditions:
            conditions.append("(" + " | ".join(genre_theme_conditions) + ")")
            
        where_clause = "where " + " & ".join(conditions) + ";"
        
        search_esc = search_string.replace('"', '\\"')
        query_body = f'search "{search_esc}"; fields {fields_str}; {where_clause} limit 8;'
        
        print(f"Trying IGDB query with rating/genre/theme filter...")
        
        try:
            results = self.query_games(query_body)
            if results:
                return results
        except Exception as e:
            print(f"First search attempt failed or errored: {e}. Trying fallback search...")
            
        # Fallback query 1: Just search string, no filters, no rating limit
        print(f"No results. Retrying with just search string...")
        fallback_query_body = f'search "{search_esc}"; fields {fields_str}; limit 8;'
        
        try:
            results = self.query_games(fallback_query_body)
            if results:
                return results
        except Exception as e:
            print(f"Fallback search attempt failed: {e}")
            
        # Fallback query 2: Genres/Themes only, no search string, rating > 60, sorted by rating desc
        if genre_theme_conditions:
            print(f"No results. Retrying by matching genre/theme filters only...")
            fallback_genre_theme_query = f'fields {fields_str}; {where_clause} limit 8; sort rating desc;'
            try:
                return self.query_games(fallback_genre_theme_query)
            except Exception as e:
                print(f"Fallback genre/theme matching failed: {e}")
                
        return []

def format_game_data(games: list) -> str:
    """Formats list of games returned from IGDB into clean text for prompt context."""
    if not games:
        return "No candidate games found."
        
    formatted = []
    for idx, game in enumerate(games, 1):
        name = game.get("name", "Unknown Game")
        summary = game.get("summary", "No summary available.")
        if len(summary) > 300:
            summary = summary[:300] + "..."
            
        rating = f"{game.get('rating', 'N/A'):.1f}" if isinstance(game.get("rating"), (int, float)) else "N/A"
        
        # Extract lists
        genres = [g.get("name") for g in game.get("genres", []) if g.get("name")]
        themes = [t.get("name") for t in game.get("themes", []) if t.get("name")]
        platforms = [p.get("name") for p in game.get("platforms", []) if p.get("name")]
        modes = [m.get("name") for m in game.get("game_modes", []) if m.get("name")]
        perspectives = [p.get("name") for p in game.get("player_perspectives", []) if p.get("name")]
        
        # Companies
        companies = []
        for ic in game.get("involved_companies", []):
            comp = ic.get("company", {})
            if comp.get("name"):
                companies.append(comp.get("name"))
                
        # Release year
        release_year = "Unknown"
        rel_date = game.get("first_release_date")
        if rel_date:
            try:
                release_year = str(time.gmtime(rel_date).tm_year)
            except (ValueError, TypeError):
                pass
                
        details = (
            f"Game {idx}: {name}\n"
            f"- Release Year: {release_year}\n"
            f"- Developer/Publisher: {', '.join(companies) if companies else 'Unknown'}\n"
            f"- Rating: {rating}/100\n"
            f"- Genres: {', '.join(genres) if genres else 'None'}\n"
            f"- Themes: {', '.join(themes) if themes else 'None'}\n"
            f"- Platforms: {', '.join(platforms) if platforms else 'None'}\n"
            f"- Modes: {', '.join(modes) if modes else 'None'}\n"
            f"- Perspective: {', '.join(perspectives) if perspectives else 'None'}\n"
            f"- Summary: {summary}\n"
        )
        formatted.append(details)
        
    return "\n".join(formatted)
