# Naviola — Navidrome + Radio menu bar player for macOS

[![Built on Radiola](https://img.shields.io/badge/Built%20on-Radiola-blue)](https://github.com/SokoloffA/radiola)

## About
Naviola is a lightweight menu bar music player for macOS that connects to your [Navidrome](https://www.navidrome.org/) self-hosted music server. It also supports internet radio via its [Radiola](https://github.com/SokoloffA/radiola) foundation.

Browse your music library, pin albums and playlists, and control playback — all from the menu bar.

## Features
* Browse Navidrome: Albums, Artists, Genres, Playlists, Search
* Pin albums, artists, playlists, and genres for quick access
* Sequential playback with auto-advance, repeat, and shuffle
* Skip/back controls, seekable progress bar
* Rich metadata display (artist, album, track)
* Internet radio support (from Radiola)
* Menu bar playback controls with now-playing info
* Very light, less than 40 megabytes

## Credits
Naviola is a hard fork of [Radiola](https://github.com/SokoloffA/radiola) by Alexander Sokolov. Thank you for building such a solid foundation.

## Building
```sh
# Run unit tests
xcodebuild test -scheme Naviola CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Build for development
xcodebuild build -scheme Naviola -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -derivedDataPath ./build
open ./build/Build/Products/Debug/Naviola.app
```
