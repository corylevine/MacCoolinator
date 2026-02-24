# CLAUDE.md

## Project overview

MacCoolinator is a Swift macOS menu bar app (SPM, no external dependencies) that overlays window titles on Mission Control thumbnails. Source lives in `Sources/MacCoolinator/`.

## Feature list maintenance

The **Features** section in `README.md` is the canonical list of user-facing features. When you add, remove, or change a feature, update that list to match. Keep entries concise — one bullet per feature with a bold label and a short description.

## Build & run

```sh
./build-app.sh          # builds release and creates build/MacCoolinator.app
swift build              # debug build only
```

## Code conventions

- Pure AppKit, no SwiftUI.
- Settings are stored via `UserDefaults` through `OverlaySettings`.
- No external dependencies — keep it that way unless there's a strong reason.
