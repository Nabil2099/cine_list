# CineList

**Discover. Save. Watch.**

CineList is a dark-themed Flutter movie discovery, watchlist, AI recommendation, and community review app built with **Material 3**, **Cubit (`flutter_bloc`)**, **TMDB REST API (`dio`)**, **Google Gemini**, **Firebase Authentication**, **Cloud Firestore**, and **Hive**.

---

## Features

### Discover
- Browse **Trending**, **Popular**, and **Top Rated** movies from TMDB.
- Filter instantly with **Genre Chips** (Action, Sci-Fi, Thriller, Comedy, Drama, and more).
- Featured movie spotlight, horizontal poster carousel, and responsive grid layout.
- **Quick-Save** bookmark button directly on movie cards to add or remove titles without leaving the feed.
- Debounced (~400ms) movie search with stale-request cancellation, **Load More** pagination, and pull-to-refresh.

### Movie Details
- High-resolution backdrop and poster artwork cached via `cached_network_image`.
- Release year, runtime, TMDB score, genres, overview, and cast list.
- **Trailers** and **Where to Watch** streaming/rent/buy provider badges powered by TMDB.
- Horizontal **More Like This** recommendations row.
- Real-time watchlist controls (**Want to Watch** / **Watched**) and **Community Reviews** with star ratings, helpful likes, and review composer.

### My Watchlist
- Real-time Cloud Firestore sync scoped per user (`users/{uid}/watchlist/{tmdbMovieId}`).
- **Watchlist Stats Card** showing total hours watched, favorite genre, and completion rate.
- Segmented **Want to Watch** and **Watched** tabs with live counts.
- **Personal Ratings & Notes** (1–5 stars + short note) when marking a movie as **Watched**.
- Local search filter and sorting by **Recently Added**, **Highest Rated**, or **Release Year**.

### CineList AI (AI Concierge)
- Personalized movie recommendations powered by **Gemini** using your saved watchlist and personal ratings.
- One-tap **Mood Picker** chips (e.g., *Mind-Bending*, *Cozy Comfort*, *Adrenaline*, *90-Min Quick Watch*).
- **Clickable Movie Picks** in chat that search TMDB and open Movie Details directly.

### Community
- Editable user profiles with display name, custom avatar, and bio (`users/{uid}`).
- Public movie reviews feed (`reviews/{reviewId}`) with star ratings, **Helpful** upvotes, and owner delete controls.
- Tap any reviewer's name or avatar to view their profile modal.

### Authentication & Preferences
- Email/password sign-up, login, password reset, form validation, and persistent sessions via Firebase Auth.
- Local Discover category persistence via **Hive**.

---

## Screenshots

| Discover | Movie Details | My Watchlist | CineList AI | Community |
|---|---|---|---|---|
| *Add screenshot* | *Add screenshot* | *Add screenshot* | *Add screenshot* | *Add screenshot* |

---

## Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter & Dart** | Cross-platform UI framework |
| **Material 3** | Dark cinematic theme & components |
| **`flutter_bloc` (Cubit)** | Predictable state management |
| **`dio`** | TMDB & Gemini HTTP client & error mapping |
| **`firebase_auth`** | Email/password authentication |
| **`cloud_firestore`** | Real-time watchlist, profiles & reviews |
| **`hive` / `hive_flutter`** | Lightweight local preferences |
| **`cached_network_image`** | Image loading & caching |
| **`get_it`** | Dependency injection |
| **`equatable`** | Value equality for states & models |
| **`url_launcher`** | Opening trailers & external links |

---

## Project Structure

```text
lib/
  main.dart
  app.dart
  firebase_options.dart
  core/
    constants/        # API & app-wide constants
    di/               # get_it service locator
    error/            # Typed exceptions
    network/          # Reusable DioClient
    routing/          # AppShell navigation & route helpers
    storage/          # Hive PreferencesService
    theme/            # Palette & Material 3 ThemeData
    utils/            # Debouncer & formatters
    widgets/          # Shared UI primitives
  shared/
    models/           # MovieSummary
    widgets/          # MovieCard & MoviePoster
  features/
    ai_chat/          # CineList AI concierge & mood picker
    auth/             # Login, registration & password reset
    community/        # User profiles, avatars & public reviews
    discover/         # Trending/popular/top-rated, genres & search
    movie_details/    # Details, trailers, providers & similar movies
    watchlist/        # Watchlist tabs, stats, ratings & sorting
firestore.rules       # Cloud Firestore security rules
.env.example          # Environment variable template
```

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (`>= 3.47` / Dart `>= 3.13`)
- A [TMDB API key](https://www.themoviedb.org/settings/api)
- A [Google Gemini API key](https://aistudio.google.com/apikey)
- A Firebase project with **Email/Password Authentication** and **Cloud Firestore** enabled

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment Variables
Copy `.env.example` to `.env` and fill in your keys:

```bash
cp .env.example .env
```

```env
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_BASE_URL=https://api.themoviedb.org/3

GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-3.5-flash-lite
```

> **Security Note:** Never commit `.env` or API keys to Git. For production apps, route API requests through a backend proxy.

### 4. Firebase & Firestore Setup
If you connect a different Firebase project, run:

```bash
flutterfire configure
```

Then deploy the included Firestore security rules:

```bash
firebase deploy --only firestore:rules
```

The rules in `firestore.rules` enforce:
- Authenticated access only (`request.auth != null`).
- Strict per-user isolation for `users/{uid}/watchlist/{movieId}`.
- Public read and owner-only write for `users/{uid}` profiles.
- Public read, owner create/edit/delete, and authenticated `likedBy` upvotes for `reviews/{reviewId}`.

---

## Running & Verification

```bash
# Run the app
flutter run

# Format, analyze, and run unit tests
dart format .
flutter analyze
flutter test
```
