# AniDash v1.16.4

## What changed

- 🎬 Fixed online episodes getting stuck on the opening spinner.
- ⚡ Removed the duplicate initial buffering gate so playback can begin as soon as the first decodable segment is ready.
- 🛡️ Restored media_kit's resilient HLS segment handling instead of replacing it with a weaker reconnect override.
- 📦 Increased the forward streaming cache capacity to at least 100 MiB, with continuous background refill.
- 📱 Enabled safe Android hardware decoding for smoother high-quality playback and lower CPU usage.
- 🔄 Added a faster startup timeout so the existing same-language source recovery can act instead of leaving an endless loader.
- 📖 Refreshed the README with current AniDash screenshots and straightforward user instructions.

Playback availability and startup speed still depend on the selected provider and network conditions. AniDash keeps the selected audio language during recovery.
