# Stremio ATV

An iOS app with an Apple TV-app-style layout (bottom tab bar, hero banner,
horizontal shelves) that speaks the standard [Stremio addon
protocol](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/manifest.md)
(`manifest.json` / `catalog` / `meta` / `stream`).

## What it does

- You add any addon by pasting its `manifest.json` URL in the **Addons** tab.
- The app lists that addon's catalogs as horizontal shelves on **Watch Now**,
  and lets you search across all installed addons in **Search**.
- Tapping a title fetches its streams from your addon(s) and plays whatever
  direct HTTP(S) media URL the addon returns, using the standard iOS video
  player (`AVKit`).

## What it deliberately does not do

This app has **no torrent/BitTorrent/magnet-link support of any kind**, and
does not bundle, recommend, or pre-configure any specific addon. If an addon
returns a stream entry that isn't a direct `http(s)://` URL (e.g. an
`infoHash`/magnet-only torrent stream), the app shows it as "unsupported" and
will not play it. It's a generic protocol client for addons you choose and
provide yourself — the same shape as pointing any podcast app at an RSS feed
you supply.

## Building

CI (`.github/workflows/build-ios.yml`) builds an **unsigned** `.ipa` using
[XcodeGen](https://github.com/yonaskolb/XcodeGen) + `xcodebuild` on a macOS
runner, since there's no Apple Developer account/certificate available in CI.

To install it on a device, resign the unsigned `.ipa` locally with your own
Apple ID, using a sideloading tool such as
[AltStore](https://altstore.io/), [Sideloadly](https://sideloadly.io/), or
Xcode itself (`xcodebuild -exportArchive` with your own signing identity, or
drag the `.app` into Xcode's Devices window).

## Local development

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`):

```bash
cd stremio-atv
xcodegen generate
open StremioATV.xcodeproj
```
