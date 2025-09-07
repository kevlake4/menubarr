# menubarr

`menubarr` is a lightweight macOS menu bar app that displays your Plex activity, in the menu bar.

- **Now Playing** – shows what’s currently streaming from your Plex server
- **Recent History** – displays recently played content via [Tautulli](https://tautulli.com/) integration
- **Auto Refresh** – updates every 10 minutes (or manually with a click)
- **Simple Settings** – configure Plex Base URL, Plex Token, and Tautulli API key

---

## Features

- Menu bar app (no Dock icon)
- **Now Playing**
  - Title, user, playback state, and transcode info
- **Recent History (Tautulli)**
  - Last few streams (movies, TV episodes, music, etc.)
  - User, watched status, and playback time
- Settings window for Plex and Tautulli configuration
- Optional notifications for activity

---

## Requirements

- macOS 14 (Sonoma) or newer
- Plex Media Server reachable from your Mac
- (Optional) Tautulli instance for recent history
- Plex **Base URL** (e.g. `http://192.168.0.10:32400`)
- Plex **Token**
- (Optional) Tautulli **API Key**

---

## Configuration

1. Launch **menubarr** — it appears in the macOS menu bar.
2. Open **Settings** (gear icon).
3. Enter the following:
   - Plex Base URL (e.g. `http://192.168.0.10:32400`)
   - Plex Token
   - Tautulli Base URL and API Key (if you want recent plays)
4. Save your settings. The app will refresh its data.

**Note:** If your Plex/Tautulli URLs use `http://` (not HTTPS), you may need to add an ATS exception for those hosts in the app’s `Info.plist`.

---

## Screenshot

Here’s menubarr showing Plex Now Playing and Recent History in the menu bar:

![menubarr screenshot](FE3032D5-6656-44CB-B071-A293A26B4115.jpeg)

---

## Roadmap

- [ ] Support for multiple Plex servers
- [ ] Artwork thumbnails for Now Playing and Recent History
- [ ] More granular notification options
- [ ] Adjustable refresh interval

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
