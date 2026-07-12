import os
import time
import json
from groq import Groq
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class GroqClient:
    def __init__(self, api_key=None):
        self.api_key = api_key or os.getenv("GROQ_API_KEY")
        self.client = None

    def _call_groq(self, messages: list, max_tokens: int = 1000, temperature: float = 0.7, json_mode: bool = False) -> str:
        """Helper to invoke the Groq API with 429 rate limit retry logic."""
        api_key = self.api_key or os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY is not configured.")

        if not self.client:
            self.client = Groq(api_key=api_key)

        kwargs = {
            "messages": messages,
            "model": "llama-3.3-70b-versatile",
            "max_tokens": max_tokens,
            "temperature": temperature
        }
        if json_mode:
            kwargs["response_format"] = {"type": "json_object"}

        try:
            completion = self.client.chat.completions.create(**kwargs)
            return completion.choices[0].message.content
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "rate_limit" in err_str.lower() or "limit exceeded" in err_str.lower():
                print("\n[Groq API] Rate limit (429) encountered. Retrying in 2 seconds...")
                time.sleep(2)
                # Retry once
                completion = self.client.chat.completions.create(**kwargs)
                return completion.choices[0].message.content
            raise e

    def extract_search_terms(self, user_input: str) -> dict:
        """
        Parses user's natural language request into search term keywords.
        Returns a dict: {"genres": [...], "themes": [...], "search": "..."}
        """
        genres_list = [
            "Point-and-click", "Fighting", "Shooter", "Music", "Platform", "Puzzle", "Racing",
            "Real Time Strategy (RTS)", "Role-playing (RPG)", "Simulator", "Sport", "Strategy",
            "Turn-based strategy (TBS)", "Tactical", "Hack and slash/Beat 'em up", "Quiz/Trivia",
            "Pinball", "Adventure", "Indie", "Arcade", "Visual Novel", "Card & Board Game", "MOBA"
        ]
        themes_list = [
            "Drama", "Non-fiction", "Sandbox", "Educational", "Kids", "Open world", "Warfare",
            "Party", "4X (explore, expand, exploit, and exterminate)", "Erotic", "Mystery",
            "Action", "Fantasy", "Science fiction", "Horror", "Thriller", "Survival",
            "Historical", "Stealth", "Comedy", "Business", "Romance"
        ]

        system_prompt = (
            "You are a game database query assistant.\n\n"
            "Given a user's natural language description of a game they want, extract:\n"
            f"1. 1-2 genres, chosen strictly from this list: {genres_list}\n"
            f"2. 1-2 themes, chosen strictly from this list: {themes_list}\n"
            "3. One short search string (1-2 words max) suitable for IGDB's text-search endpoint. "
            "It must be a core keyword matching game names (e.g. 'mario', 'space', 'builder', 'cyberpunk') "
            "rather than a descriptive phrase. If they describe a genre like 'cozy building games', "
            "the search string could be 'builder' or 'cozy'.\n\n"
            "Respond ONLY in JSON format like this:\n"
            '{"genres": ["Simulator", "Strategy"], "themes": ["Sandbox"], "search": "builder"}\n'
            "Do not include any other text."
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_input}
        ]

        # Use JSON mode for reliable extraction
        response_text = self._call_groq(messages, max_tokens=150, temperature=0.2, json_mode=True)
        try:
            return json.loads(response_text)
        except json.JSONDecodeError:
            # Simple manual parsing fallback if JSON is somehow invalid
            print("Warning: Failed to parse Groq extraction JSON. Trying manual cleanup.")
            # Basic cleanup: find the first { and last }
            start = response_text.find("{")
            end = response_text.rfind("}")
            if start != -1 and end != -1:
                try:
                    return json.loads(response_text[start:end+1])
                except json.JSONDecodeError:
                    pass
            # Default fallback
            return {"genres": [], "themes": [], "search": user_input}

    def correct_game_spelling(self, raw_names_str: str) -> list:
        """Corrects typos in user's video game names list using Groq."""
        system_prompt = (
            "You are a video game name correction assistant.\n"
            "Given a list of video game names that may contain spelling mistakes or typos, "
            "return the corrected, official names of these games. If a name is already correct, "
            "leave it as is. If a name is completely unrecognizable, omit it.\n\n"
            "Respond ONLY in JSON format containing an array of strings under the key 'corrected_names', e.g.:\n"
            '{"corrected_names": ["Hollow Knight", "The Witcher 3: Wild Hunt", "Dark Souls"]}'
        )
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Correct this list of games: {raw_names_str}"}
        ]
        
        response_text = self._call_groq(messages, max_tokens=200, temperature=0.1, json_mode=True)
        try:
            data = json.loads(response_text)
            return data.get("corrected_names", [])
        except json.JSONDecodeError:
            print("Warning: Failed to parse spell check JSON.")
            return [n.strip() for n in raw_names_str.split(",") if n.strip()]

    def recommend_games(self, user_input: str, profile: dict, formatted_games: str) -> str:
        """
        Queries Groq with the recommendation prompt incorporating candidate games, taste profile, and PC specs.
        Recommends up to 5 games with hardware compatibility analysis.
        """
        system_prompt = (
            "You are an expert game recommender who deeply understands player psychology, game design, "
            "and system requirements. You give thoughtful, specific, personalized recommendations with genuine insight."
        )

        # Truncate profile details to keep prompts short and focus key terms
        liked = ", ".join(profile.get("liked", [])) or "None"
        disliked = ", ".join(profile.get("disliked", [])) or "None"
        liked_genres = ", ".join(profile.get("liked_genres", [])) or "None"
        liked_themes = ", ".join(profile.get("liked_themes", [])) or "None"
        disliked_genres = ", ".join(profile.get("disliked_genres", [])) or "None"
        notes = profile.get("notes", "No preference notes yet.")
        
        # System specifications
        specs = profile.get("system_specs", {})
        cpu = specs.get("cpu", "Not specified")
        gpu = specs.get("gpu", "Not specified")
        ram = specs.get("ram", "Not specified")
        storage = specs.get("storage", "Not specified")
        desc = specs.get("description", "Not specified")
        specs_str = f"CPU: {cpu}, GPU: {gpu}, RAM: {ram}, Storage: {storage} (General Spec: {desc})"

        user_content = (
            f'Here is what the user is looking for:\n\n'
            f'"{user_input}"\n\n'
            f'Here is the user\'s taste profile:\n'
            f'- Games they liked: {liked}\n'
            f'- Games they disliked: {disliked}\n'
            f'- Preferred genres: {liked_genres}\n'
            f'- Preferred themes: {liked_themes}\n'
            f'- Disliked genres: {disliked_genres}\n'
            f'- Notes: {notes}\n\n'
            f'Here is the user\'s PC Hardware Specifications:\n'
            f'- {specs_str}\n\n'
            f'Here are candidate games fetched from the game database:\n\n'
            f'{formatted_games}\n\n'
            f'Based on the user\'s request, taste profile, and PC specifications, recommend UP TO 5 games from this list '
            f'(or fewer if there are not enough strong candidates). '
            f'If a game they\'ve already played is in the list, skip it and pick the next best.\n\n'
            f'IMPORTANT: Keep your explanations very concise, direct, and limited to 1-2 short sentences. '
            f'Do not write long walls of text. Make it easy to read and scan in a terminal.\n\n'
            f'Format your response by listing each game sequentially exactly as (make sure to use the exact Nerd Font glyphs):\n\n'
            f' GAME: [Game Name]\n\n'
            f' WHY YOU\'LL LOVE IT: [1-2 sentences of personalized reasoning]\n\n'
            f'󰓎 BEST FOR: [1 sentence on the ideal player for this]\n\n'
            f' COMPATIBILITY: [Rating ( EXCELLENT /  PLAYABLE /  UNPLAYABLE) - 1-sentence estimation based on user\'s hardware specifications]\n\n'
            f'---'
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content}
        ]

        # Set temperature to 0.7 as requested
        return self._call_groq(messages, max_tokens=1500, temperature=0.7)

    def summarize_profile(self, profile: dict) -> str:
        """
        Regenerates profile notes by summarizing the user profile into 1-2 sentences.
        """
        system_prompt = (
            "You are a user profile analysis assistant.\n"
            "Summarize the user's taste profile into a concise 1-2 sentence description (e.g. 'Prefers single player, story-rich, atmospheric games. Dislikes extreme difficulty.').\n"
            "Do not output anything other than the 1-2 sentence summary."
        )

        liked = ", ".join(profile.get("liked", [])) or "None"
        disliked = ", ".join(profile.get("disliked", [])) or "None"
        liked_genres = ", ".join(profile.get("liked_genres", [])) or "None"
        liked_themes = ", ".join(profile.get("liked_themes", [])) or "None"
        disliked_genres = ", ".join(profile.get("disliked_genres", [])) or "None"
        old_notes = profile.get("notes", "")

        user_content = (
            f"Please summarize this player taste profile:\n"
            f"- Liked Games: {liked}\n"
            f"- Disliked Games: {disliked}\n"
            f"- Liked Genres: {liked_genres}\n"
            f"- Liked Themes: {liked_themes}\n"
            f"- Disliked Genres: {disliked_genres}\n"
            f"- Current Notes: {old_notes}"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content}
        ]

        summary = self._call_groq(messages, max_tokens=150, temperature=0.5)
        return summary.strip()

    def assess_compatibility_batch(self, games_list: list, system_specs: dict) -> dict:
        """
        Uses Groq in JSON mode to evaluate compatibility (EXCELLENT, PLAYABLE, UNPLAYABLE)
        for a batch list of games based on the user's system specs.
        Returns a dict mapping game names to their rating and reason:
        {
          "compatibility": [
             {"name": "Game Name", "rating": "EXCELLENT", "reason": "Reason string"},
             ...
          ]
        }
        """
        if not games_list:
            return {"compatibility": []}

        # Truncate descriptions to save context window tokens
        simplified_games = []
        for g in games_list:
            name = g.get("name", "Unknown Game")
            summary = g.get("summary", "")
            if len(summary) > 200:
                summary = summary[:200] + "..."
            
            # Map genres, themes, platforms to simple list of names if dicts
            genres = []
            for gen in g.get("genres", []):
                if isinstance(gen, dict) and gen.get("name"):
                    genres.append(gen.get("name"))
                elif isinstance(gen, str):
                    genres.append(gen)
                    
            themes = []
            for thm in g.get("themes", []):
                if isinstance(thm, dict) and thm.get("name"):
                    themes.append(thm.get("name"))
                elif isinstance(thm, str):
                    themes.append(thm)
                    
            platforms = []
            for plt in g.get("platforms", []):
                if isinstance(plt, dict) and plt.get("name"):
                    platforms.append(plt.get("name"))
                elif isinstance(plt, str):
                    platforms.append(plt)
                    
            simplified_games.append({
                "name": name,
                "summary": summary,
                "genres": genres,
                "themes": themes,
                "platforms": platforms
            })

        system_prompt = (
            "You are a system hardware compatibility evaluator.\n"
            "Given a user's PC specifications and a list of games, evaluate how well each game is expected to run on their hardware.\n"
            "Assign one of these ratings:\n"
            "- EXCELLENT: Runs at high settings and frame rates (lightweight/indie games, or matches specs easily).\n"
            "- PLAYABLE: Runs fine at medium/low settings (demanding modern games on decent hardware).\n"
            "- UNPLAYABLE: Will not run or run extremely poorly (heavy games on potato/low-end systems, or unsupported OS).\n\n"
            "Respond ONLY in JSON format in this structure:\n"
            '{\n'
            '  "compatibility": [\n'
            '    {\n'
            '      "name": "Game Name",\n'
            '      "rating": "EXCELLENT" | "PLAYABLE" | "UNPLAYABLE",\n'
            '      "reason": "1 brief sentence explaining why it receives this rating based on the hardware specs."\n'
            '    }\n'
            '  ]\n'
            '}\n'
            "Ensure the game name matches the input exactly."
        )

        user_content = (
            f"User PC Specifications:\n"
            f"- CPU: {system_specs.get('cpu', 'Unknown')}\n"
            f"- GPU: {system_specs.get('gpu', 'Unknown')}\n"
            f"- RAM: {system_specs.get('ram', 'Unknown')}\n"
            f"- Storage: {system_specs.get('storage', 'Unknown')}\n"
            f"- General Rig Class: {system_specs.get('description', 'Unknown')}\n\n"
            f"Games to Evaluate:\n"
            f"{json.dumps(simplified_games, indent=2)}"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content}
        ]

        response_text = self._call_groq(messages, max_tokens=1500, temperature=0.1, json_mode=True)
        try:
            return json.loads(response_text)
        except json.JSONDecodeError:
            print("Warning: Failed to parse Groq batch compatibility JSON. Using default fallback.")
            # Fallback to default PLAYABLE for all
            fallback = {"compatibility": []}
            for g in games_list:
                fallback["compatibility"].append({
                    "name": g.get("name"),
                    "rating": "PLAYABLE",
                    "reason": "Standard playable estimation."
                })
            return fallback
