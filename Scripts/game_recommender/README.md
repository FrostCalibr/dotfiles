# AI-Powered Game Recommendation System

A command-line Python application that provides highly personalized, context-aware video game recommendations. It extracts preferences and themes from your natural language requests, pulls real-time candidate games from the official **IGDB database**, and uses **Groq's Llama 3.3 70B** model to analyze and deliver a tailor-made recommendation. Over time, the app maintains a local user profile that learns from your likes and dislikes.

---

## 🛠️ Tech Stack
- **Language**: Python 3.10+
- **LLM**: Groq Cloud API (`llama-3.3-70b-versatile`)
- **Game Database**: IGDB API (via Twitch OAuth2 credentials)
- **Local Cache & Profile**: Saved locally as `user_profile.json` and `.env`

---

## 🚀 Setup & Installation

### Step 1: Get API Keys

1. **Groq API Key**:
   - Register or log in at [console.groq.com](https://console.groq.com/).
   - Generate a free API key.

2. **IGDB Developer Credentials**:
   - Log in or sign up with a [Twitch Account](https://www.twitch.tv/).
   - Navigate to the [Twitch Developer Console](https://dev.twitch.tv/console).
   - Click **Register Your Application**.
   - Fill in the details (e.g., Name: `Game Recommender`, Category: `Application`, OAuth Redirect URL: `http://localhost`).
   - Create the app and note down the **Client ID**.
   - Click **New Secret** and copy the **Client Secret** (save it somewhere secure, as it won't be displayed again).

### Step 2: Install Dependencies

Open your terminal, navigate to the project directory, and run:

```bash
pip install -r requirements.txt
```

### Step 3: Run the Application

Start the program by running:

```bash
python main.py
```

- **First Run Setup Wizard**: If you don't have a `.env` file configured, the application will prompt you in the console for your keys and save them to a `.env` file automatically.
- **Start Chatting**: Describe the kind of game experience you want in natural language (e.g., *"something atmospheric and dark, where you feel lost like in hollow knight"*).

---

## 🧩 How It Works Under the Hood

1. **Extracted Search Terms**: The Groq LLM parses your natural language input to find the most relevant genre/theme tags and database query strings.
2. **IGDB Query**: The app searches IGDB with a rating filter (`rating > 60`) + genre/theme tags. If no results match, it automatically falls back to search term-only lookup.
3. **Recommendation Reasoning**: Groq compares the fetched games with your `user_profile.json` taste history, filtering out games you've already played.
4. **Learning Cycle**:
   - Feedback on whether you liked the recommendation updates your liked/disliked lists, genres, and themes.
   - Every 5 feedback interactions, Groq automatically updates a 1-2 sentence profile description (`notes`) to refine recommendations in future runs.

---

## 📂 File Structure

```text
game_recommender/
├── main.py           # Application entry point & console CLI loop
├── igdb_client.py    # All Twitch OAuth / IGDB API querying logic
├── groq_client.py    # Groq API wrappers & parsing prompts
├── profile.py        # Local JSON user profile persistence & logic
├── .env              # Generated API credential storage (ignored by Git)
├── user_profile.json # Generated user profile cache (ignored by Git)
└── requirements.txt  # Python package dependencies
```
