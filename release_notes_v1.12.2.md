## ⚡ What's New in v1.12.2

### 📱 Automatic Picture-in-Picture (PiP) on Swipe to Home
- **Seamless Multitasking**: Swiping up to Home or pressing the Home button while watching an anime automatically transitions into smooth Picture-in-Picture (PiP) mode without needing to manually tap the PiP button.

### ⏰ Continue Watching Background Reminders Restored
- **Fixed Notification Trigger**: Corrected an internal database identifier in background tasks so "Continue Watching" reminders for paused anime now reliably notify you after a couple of days of inactivity.

### 📁 Smart Download Organization
- **Structured Download Folders**: Downloads now actively respect your chosen folder structure (`Anime/Episode`, `Anime`, or `Flat`) in Download Settings, keeping your local storage clean and well-organized.
- **Enforced Wi-Fi Only Downloads**: When "Wi-Fi Only" is toggled on, downloads automatically verify your connection before starting and wait gracefully if you are on cellular data.

### 📊 Anime Tracker Polish
- **Real Tracker Attributes**: Replaced dummy placeholder dates in the AniList/MAL tracking bottom sheet with dynamic rewatch count and profile visibility information.

### ⚙️ Instant UI Reactivity & Permissions Management
- **Immediate Layout Switching**: Toggling the Experimental New UI instantly refreshes the Home screen layout without requiring an app restart.
- **Permissions Revoke Shortcut**: Attempting to disable storage or notification permissions in-app now provides a direct button to Android System Settings.

### 📚 Manga Tab Extensions Shortcut
- **One-Tap Extension Setup**: If no manga extension is installed yet, the Manga screen now displays an instant "Install Extensions" button directing you straight to the extensions manager.

### 🛡️ Authentication Hardening
- **MyAnimeList Safety**: Safe OAuth client initialization preventing crashes on desktop and providing clear feedback on missing credentials.

---

**Package:** com.anidash.anime  
**Version:** 1.12.2 (56)  
