# JellyHome Architecture

## Overview
JellyHome is a SwiftUI client for Jellyfin and Seerr/Jellyseerr. The app is intentionally free, with all features available once the user connects to their servers. The app uses real server data only. No UI is shown before authentication.

## App Flow
1. `ContentView` checks `SessionStore.isAuthenticated`.
2. If not authenticated, `ConnectView` prompts for Jellyfin and Seerr URLs plus Jellyfin credentials.
3. On successful login, the `MainTabView` renders and each tab loads real data via view models.
4. Admin UI is only visible when the Jellyfin user has administrator privileges.

## Data Architecture

### Session Management
- `SessionStore` persists server URLs and username in iCloud Key-Value Store.
- Tokens are stored in Keychain using `KeychainStore`.
- `SessionStore.signIn(password:)` performs:
  - Jellyfin login via `/Users/AuthenticateByName`.
  - Fetches `/Users/Me` to determine admin privileges.
  - Seerr login via `/api/v1/auth/jellyfin` when a Seerr URL is set.
- `SessionStore` tracks `displayName`, `isAdmin`, and a `lastSignInWarning` for partial Seerr failures.

### Networking
- `APIClient` wraps URLSession with JSON encoding/decoding and status validation.
- Error responses surface API-provided messages to aid troubleshooting (401, 404, etc.).
- Jellyfin requests send `X-Emby-Authorization` and `X-Emby-Token`.
- Seerr requests use `Authorization: Bearer <token>`.

### View Models
- `HomeViewModel`:
  - `/Users/{userId}/Items/Resume` for Continue Watching.
  - `/Users/{userId}/Items/Latest?IncludeItemTypes=Movie` for Movies (also hero items).
  - `/Users/{userId}/Items/Latest?IncludeItemTypes=Series` for Series.
- `CatalogViewModel`:
  - `/api/v1/discover/trending`, `/popular`, `/upcoming` with fallbacks to `/discover/movies` and `/discover/tv`.
- `LibraryViewModel`:
  - `/Library/MediaFolders` for library folders.
  - `/Users/{userId}/Items/Latest?IncludeItemTypes=Movie` for Recent.
- `SearchViewModel`:
  - Jellyfin `/Items?SearchTerm=...`.
  - Seerr `/api/v1/search?query=...`.

### Media Models
- `JellyfinItem` includes `ImageTags`, `RunTimeTicks`, and `UserData` to compute playback progress.
- `MediaItem` is the shared UI model for posters and hero cards.
- `MediaItem.sourceId` is used to open Jellyfin playback or create Seerr requests.

## UI System
- `Theme` defines the liquid dark color palette and typography.
- `LiquidBackground` provides a gradient and soft shapes to mimic glass.
- `GlassCard` and `GlassButtonStyle` standardize blurred, rounded surfaces.
- `MediaDetailView` handles playback for Jellyfin items and requests for Seerr items.

## Offline + Player (Scaffolding)
- `PlayerCoordinator` wraps `AVPlayer` for playback control.
- `DownloadManager` is a placeholder to integrate `AVAssetDownloadURLSession` later.

## Extending the App
- Add more Jellyfin endpoints in `JellyfinClient` and map to `MediaItem`.
- Add request-management UI using `SeerrClient` methods for approve/deny.
- Expand the player to support PiP, AirPlay, and download management.

## Troubleshooting
- If Home/Catalog are empty, confirm Jellyfin/Seerr URLs and credentials.
- Ensure the Jellyfin server is reachable from the device network.
- If Seerr auth fails, verify Jellyseerr/Overseerr auth endpoints and update `SeerrClient` accordingly.
