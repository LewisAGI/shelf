# Shelf

Personal, phone-only PDF library with page voice notes. Working title — Lewis may rename.

v1 is a **single-user, this-device** library. No cloud sync, no accounts, no App Store listing, no Android.

## Clone here — not Documents/Grok

Put the project on the local disk:

```bash
mkdir -p ~/Developer
git clone https://github.com/LewisAGI/shelf.git ~/Developer/shelf
cd ~/Developer/shelf
```

**Do not** clone into `~/Documents/Grok` (or any iCloud Desktop & Documents folder). The iCloud File Provider breaks iOS codesign when Xcode / Flutter writes build products under iCloud.

Use **DeviceHub** or `flutter run` from Xcode — not `Simulator.app` as the daily driver.

Expected local toolchain: **Flutter 3.47** and **Xcode 27**.

## Run on iPhone (Simulator or device)

```bash
cd ~/Developer/shelf
flutter pub get
flutter run
```

Pick an iPhone simulator from DeviceHub / `flutter devices`, or a physical iPhone.

First-run iOS build: open `ios/Runner.xcworkspace` in Xcode if you need to pick a development team for a physical device.

## Demo path

1. **Import a PDF** — Library → **Import PDF** (Files picker). The file is copied into the app Documents sandbox (`…/Documents/library/`).
2. Open the PDF. **Long-press** the page to place a note at that position (PDF text selection is off so the press opens the composer, not a selection box). X/Y sliders fine-tune the marker. Tap a marker to reopen a note. A small square marker appears.
3. **Dictate** (microphone) or type. On a physical iPhone, speech-to-text runs with British English. After dictation, filler words (`um`, `uh`, `like`, …) are stripped automatically; **Clean up filler** does the same pass by hand.
4. New notes start on the **orange** colour label (“General note”). Tap the colour **square** to the right of the microphone to pick another Settings colour.
5. **Show / hide markers** from the top chrome (eye icon) — outside the PDF, so it does not steal page gestures.
6. Tap a marker to reopen the note. Markers use the label colour.
7. Bottom bar: previous / next page, and the unfold control to **jump to a page number** or a **chapter** if the PDF has a table of contents.
8. **Notes** tab: keyword search, filter by colour label, tap a row to open that PDF on that page. The reader waits until the viewer is ready, jumps to the page, brings the marker into view, then opens the editor — no fixed delay.
9. **Settings**: edit the seeded labels (orange = general note, purple = further research), add your own colours and meanings. They persist with the local library.

## What’s stubbed / limited

| Area | v1 behaviour |
| --- | --- |
| **Speech on Simulator** | Apple Speech is unreliable or unavailable in the Simulator. The editor stays usable: type the note. On a **physical iPhone**, grant Speech Recognition + Microphone when prompted (`Info.plist` strings are already set). If device dictation still fails, add the Speech Recognition capability on the Runner target in Xcode. |
| **Android** | Out of scope. The project is iOS-only (`flutter create --platforms=ios`). |
| **Cloud / accounts / App Store** | Not started. Library is local SQLite + sandbox files. |
| **Commercial polish** | Intentionally light: readable British English chrome, white canvas, orange accents. |

## Persistence

SQLite (`sqflite`) in the app database directory:

- `documents` — imported PDFs
- `notes` — `document_id`, 1-based `page`, normalised `x`/`y` (0–1, origin top-left), `text`, `color_label_id`, timestamps
- `color_labels` — user-defined colour + meaning; one row marked `is_default` (seeded orange)

PDF bytes live under the application **Documents** directory, not iCloud.

## Tests

```bash
flutter analyze
flutter test
```

Unit tests cover filler cleanup, the note / colour-label persistence model (`toMap` / `fromMap`, default orange seed, coordinate clamping), `FirstTapTracker` (legacy double-tap pairing), the notes-hub open sequence, and the Grok-style composer (pill, mic, 4-line field, colour square, X/Y sliders, long-press create path).
