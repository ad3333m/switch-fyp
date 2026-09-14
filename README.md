# ForYou — a TikTok-style For You page for Switch homebrew

A homebrew `.nro` for a **modded (CFW) Nintendo Switch** that opens a native "For You"
feed styled like TikTok — vertical swipe feed, double-tap-to-like heart burst, comment
sheet, favourites, repost/share sheet, follow button, animated action rail, progress bar.

## Why this isn't a native-rendered app

There is no public TikTok API, and Switch homebrew has no general-purpose H.264/VP9/AV1
video decoding pipeline available out of the box (this is genuinely hard — even
long-running homebrew video projects like NXMP took years, and the more comparable
TizenTube-NX project still lists video playback as "not implemented"). Writing a codec
from scratch was out of scope here.

So `ForYou` uses the same trick homebrew YouTube clients (e.g. LennyTube) use: the `.nro`
is a tiny native launcher that brings up Wi-Fi, then opens the **console's built-in Web
Applet** pointed at a hosted web app. That gives real `<video>` playback (via the
console's own browser engine) and full CSS/JS control over the UI, so the feed, gestures
and animations can match TikTok closely — while every launch fetches the feed and video
live over the network, nothing is pre-imported onto the SD card.

## Project layout

```
launcher/        libnx C++ source + Makefile — builds ForYou.nro
webapp/          the actual "For You" feed UI (HTML/CSS/JS)
  index.html
  style.css
  app.js
  feed.json      mock feed data (sample video clips + captions/comments)
.github/workflows/build.yml   CI: deploys webapp to GitHub Pages, then builds the .nro
                               pointed at that Pages URL
```

## How the pieces fit together

1. `webapp/` is deployed to **GitHub Pages** by the `deploy-webapp` job.
2. `build-nro` then compiles `launcher/main.cpp` with `devkitpro/devkita64`, baking the
   live Pages URL in as `FORYOU_URL` (`make FORYOU_URL=https://<you>.github.io/<repo>/`).
3. The resulting `ForYou.nro` is uploaded as a workflow artifact.
4. On the Switch, launching `ForYou` connects Wi-Fi and opens the Web Applet at that URL
   — the feed and every video clip are fetched live over the network each time.

## Getting the build

After a push to `main` (or a manual run), download the `ForYou-nro` artifact from the
Actions run, then copy `ForYou.nro` to:

```
sd:/switch/ForYou/ForYou.nro
```

Launch it from the Homebrew Menu. Requires a homebrew-capable (CFW) console — this repo
only automates the build, it doesn't provide or explain how to get homebrew access.

## Building locally

Requires [devkitPro](https://devkitpro.org/wiki/Getting_Started) with the `switch-dev`
package group (provides `devkitA64` + `libnx`).

```bash
cd launcher
make FORYOU_URL=https://your-user.github.io/your-repo/
```

For the web app, any static file server works, e.g.:

```bash
cd webapp
python -m http.server 8000
```

## Content / video clips

`feed.json` currently points at Google's public sample video bucket
(`commondatastorage.googleapis.com/gtv-videos-bucket/sample/*.mp4`) as placeholder
content — real TikTok videos aren't available through any API. Swap `feed.json` and the
`video` URLs for your own hosted clips to change what's in the feed; nothing needs to be
rebuilt into the `.nro` since it's fetched at runtime.

## Persistence

Likes, favourites, reposts, follows and comments you add are saved to the browser's
`localStorage` inside the Web Applet, gzip-compressed (via `CompressionStream`) before
being stored, and reloaded on the next launch on the same console. Note that some CFW/
Web Applet configurations sandbox or clear this storage between launches — this is a
platform limitation, not something the app controls.

## Scope notes

- Only a "For You" page is implemented (no Following feed, no Shop, no friends feed), as
  requested.
- Likes, comments, favourites (bookmarks) and reposts/shares are all implemented with
  TikTok-style counts, sheets, and tap/double-tap animations.
- Video content is placeholder/sample clips (see above) since real TikTok content isn't
  obtainable — the UI and interaction layer is what's built to match TikTok, not a scrape
  of TikTok's actual catalog.
