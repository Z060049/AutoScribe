# AutoScribe

AutoScribe is a native macOS menu-bar app for recording microphone and system audio, sending the capture through an API-first transcription/summarization flow, and exporting Markdown notes.

## Current MVP Build

- Native Swift/SwiftUI menu-bar utility
- Manual start/stop from the menu bar
- Double-tap Command global shortcut
- First-run consent checklist
- Microphone capture via AVFoundation
- System audio capture prototype via ScreenCaptureKit
- OpenAI transcription and summarization provider
- Markdown export to `~/Documents/AutoScribe/`
- Settings for OpenAI key, output folder, inactivity timeout, summary depth, and consent reminder

## Run

For permission testing, use the dev app bundle:

```sh
./scripts/build-dev-app.sh
open .build/AutoScribe.app
```

Then open `System Settings > Privacy & Security > Accessibility` and enable `AutoScribe`.

If `AutoScribe` is not listed, click the `+` button and choose:

```text
AutoScribe/.build/AutoScribe.app
```

You can also run the raw Swift package executable, but macOS permissions may appear under the launching app instead of AutoScribe:

```sh
swift run AutoScribe
```

## Test

```sh
swift test
```

For a production distributable, sign and notarize the app bundle.
