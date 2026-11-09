# Auri

Auri · a Brew app.

A standalone Flutter text-to-speech app for Android and web, extracted from
NeuroBrew without changing or removing NeuroBrew's reader.

- **Automatic voice:** press Read aloud and Auri reads with your Kokoro server
  when it answers, and with the device's own voice when it doesn't (or before
  you've set it up). No account or backend; works offline with a device voice.
- **Settings** (gear icon): choose Automatic, Kokoro only, Device voice only, or
  Other API, each shown with whether it's available right now.
- **Where the voice comes from:** while reading, a card shows the voice and its
  source (your Kokoro server, this device, or the API host), and why Automatic
  fell back if it did.
- **Other API + MP3:** OpenAI (`tts-1`, `alloy`) or any HTTPS OpenAI-compatible
  endpoint, generated as an MP3 to play or export.
- **A minimal reader:** a plain writing surface (title, text, word count and
  listening time), and while reading, the text itself with the current sentence
  and spoken word highlighted, scrolling along. A bottom player holds the voice,
  speed (applies instantly), play/pause and a menu (export, start over, clear).
  Ctrl/⌘+Enter plays and pauses.
- **Colour themes:** Auri (the default), Violet, Neon, Ocean, Forest, Ember, Rose
  and Graphite. The Auri theme takes its navy, violet and ice blue from the icon.
  Each palette supports System, Light and Dark modes. Every
  palette is tested to meet WCAG AA contrast (`test/palette_contrast_test.dart`).
- Import TXT, Markdown, text-based PDF, and EPUB documents locally.
- Pause/resume, long-text chunking, and a layout that adapts from phones to desktops.

## Run

Install Flutter stable with Dart 3.12.2 or later, then:

```sh
flutter pub get
flutter run -d chrome
# Or with a connected Android device:
flutter run
```

```sh
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

There are no private Git dependencies and no Supabase setup. Android release
signing must be configured with your own keystore before store distribution;
the generated development build configuration uses debug signing.

## Reading modes

Settings → **Reading mode**:

| Mode | Reads with | When it can't |
|---|---|---|
| Automatic (default) | The Kokoro server, then Kokoro on this phone, then the device voice (or the phone first, if you choose) | Falls to the next, also mid-reading |
| Kokoro server only | Your Kokoro server | Shows why (offline, token rejected, not set up) |
| Kokoro on this phone | A downloaded Kokoro model, on the phone itself (Android) | Asks you to download a model |
| Device voice only | The OS or browser voice | Asks you to install a system voice |
| Other API · MP3 export | OpenAI or your endpoint, as an MP3 | Shows the provider's error |

**Auri · Read aloud** in Android's text-selection menu (often under ⋮; the
plain "Read aloud" next to Copy is Android's own Select to Speak) reads the
selection without opening Auri: the app you selected in stays in front. The
voice is set in Settings → *Read aloud in other apps*:

| Choice | Reads with |
|---|---|
| Fastest available (default) | The Kokoro server if it answers within 10 s, then Kokoro on this phone, then the device voice |
| Kokoro server | The Kokoro server, else the device voice |
| Kokoro on this phone | The downloaded model, else the device voice |
| Device voice | The device voice |

A "Reading aloud" notification names the voice (and why, after a fallback)
and has **Stop** and **Device voice**, which carries on from the same place.
Selecting new text replaces the reading. It runs without the app, so it can
use the Kokoro server only when the token is remembered. Under the hood a
background Flutter engine (`ReadAloudService.kt` →
`lib/features/read_aloud/selection_reader.dart`) runs the same Dart voices as
the app.

Text shared to Auri (Share) opens the app and reads with the device voice.

Each mode shows its availability in Settings. Kokoro's is checked by asking the
server for its voice list, at launch, when Settings opens, on **Check now**, and
before reading (a result under a minute old is reused).

### Kokoro

[Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) is a self-hosted,
OpenAI-compatible neural voice server. Auri can use the same one Synapse reads
aloud with: no provider charges, and 70-odd voices (default `af_heart`, the full
list appears in Settings once the server answers). Bake the server's address
into a build so you only enter the token:

```sh
flutter build apk --release --dart-define=KOKORO_URL=https://<your-server>
```

Or type the address in Settings. Kokoro reads chunk by chunk, making the next
chunk while the current one plays, and keeps this session's chunks so pausing
and resuming doesn't make them again. A reading played through from the start
can be exported as an MP3.

On web the server must answer CORS preflight requests; a token gate that rejects
every request without the token (as Synapse's Caddy setup does) blocks the
browser, so use the Android app there.

### Kokoro on this phone

Android only. Kokoro-82M v1.0 runs on the phone through
[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx): no Mac, no connection,
and the text never leaves the phone. Same 54 voices as the server.

Nothing downloads on its own. Settings → **Voice models on this phone** lists
two models with their sizes; each downloads only after you confirm, and can be
cancelled or deleted:

| Model | Download | On the phone | Speed (M1 Pro CPU, 6 threads) |
|---|---|---|---|
| Kokoro · full quality (recommended) | 333 MB | 395 MB | 9.4 s of speech in 2.0 s |
| Kokoro · compact (int8) | 126 MB | 186 MB | 9.3 s of speech in 7.7 s |

int8 is smaller but much slower on ARM CPUs, so the full model is the one to
use on a recent phone. Pieces are made while the previous one plays, starting
with a short one so the first audio comes quickly; a whole reading can be
exported as WAV.

Quality is close to the server: same model and voices. The server's text
front end is better with numbers and abbreviations (it says "twenty
twenty-six", the phone "two thousand twenty-six"). Auri pins sherpa-onnx
**1.13.8**: in 2.x the espeak-ng fallback was removed and Kokoro silently skips
every word not in its lexicon, names and numbers included.

`test/local_kokoro_live_test.dart` runs the real engine on a desktop host when
pointed at an unpacked model (see the file).

### Other API

1. In Settings, choose **Other API · MP3 export** and a provider: OpenAI or
   Custom. Switching provider clears the key, so a key typed for one provider is
   never sent to another.
2. Enter a personal API key, model, and voice. Only use an endpoint you trust
   with that key and your text.
3. Press play. Auri generates the MP3 first (this sends the text to the
   provider and may incur charges; long documents need several requests), then
   plays it. Speed is a playback setting, so the exported MP3 is at 1×.
4. Export it from the player's menu.

The API follows the [OpenAI speech contract](https://developers.openai.com/api/reference/resources/audio/subresources/speech/methods/create).
Other providers must implement that contract and return MP3 bytes. Web providers
must permit CORS. Requests use HTTPS, do not follow redirects, and time out after
90 seconds. Cancellation prevents subsequent chunks but cannot undo a provider
request that has already been processed.

## Privacy and security

API keys are entered at runtime and remain in memory only. They are never
included in source, build-time defines, preferences, URLs, logs, or committed
files. The one exception is opt-in: **Remember token on this device** keeps the
Kokoro token in Android's encrypted storage (flutter_secure_storage, keys in the
Android Keystore) until you turn it off. It isn't offered on web. App backup is
disabled so the stored token never leaves the phone. Non-secret settings (mode,
Kokoro address and voice) are kept in app preferences.

No application backend receives your key. On web, a key is present in your
browser memory and outbound request; never embed a shared production key in a
public deployment.

Documents and generated audio also remain in memory until explicitly exported.
Closing/reloading the app loses the draft, the audio, and any key not remembered. Device speech is
provided by the OS/browser; some voices use a network service. Install an
appropriate offline voice to read without a connection.

## Limits

- MP3 export needs Kokoro or Other API; device TTS does not produce a portable MP3.
- Scanned PDFs require OCR elsewhere. DRM-protected EPUBs are not supported.
- Device resume restarts at the latest word callback (or chunk start if the
  engine provides no progress). API playback restarts the MP3 after pausing.
- MP3 chunks are joined as MPEG audio frames, preserving the original approach
  from NeuroBrew. Some players may show approximate duration/seek behavior.
- No cloud reading library, background audio service, or account sync.

## Provenance

Document parsing, text chunking, MP3 joining, and theme tokens are adapted from
[bufferBrew/NeuroBrew](https://github.com/bufferBrew/NeuroBrew).
This repository starts with new history and includes no original environment
files, deployment configuration, credentials, or user documents.

## App icon

The neon violet soundwave artwork in `assets/branding/app_icon.png` is the source
for Android launcher and web icons. Regenerate them with
`dart pub global run flutter_launcher_icons` after installing it with
`dart pub global activate flutter_launcher_icons 0.14.4`. The in-app logo is a 96 × 96 copy of the same
artwork.
