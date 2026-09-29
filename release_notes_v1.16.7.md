# AniDash v1.16.7 — Library & Episode Artwork Polish ✨

## Fixed

- 🖼️ Continue Watching now permanently saves and reuses the real episode thumbnail across navigation and rebuilds.
- 🎨 Anime cover art is used only as a final fallback when an episode thumbnail is genuinely unavailable.
- ⚡ Episode discovery now starts alongside About/details enrichment, so the Episodes tab no longer waits behind the slower metadata request.
- 🔁 Automatically retries episode discovery once with the enriched AniList/Jikan title when the initial source title cannot be matched.

## Added

- 👇 Pull-to-refresh is available in every Library category, including Watching, Plan to Watch, Completed, On Hold, Repeating, Dropped and Favorites.
- ✅ Pull-to-refresh also works on empty, loading, error and short-list states.

## Verification

- ✅ Full Flutter test suite: 56/56 passed.
- ✅ Full static analysis: no issues found.
