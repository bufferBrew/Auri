# Voxen

Voxen · a Brew app (VoiceBrew until 2026-11-07).

A standalone Flutter text-to-speech app for Android and web, extracted from
NeuroBrew without changing or removing NeuroBrew's reader.

- **Automatic voice:** press Read aloud and Voxen reads with your Kokoro server
  when it answers, and with the device's own voice when it doesn't (or before
  you've set it up). No account or backend; works offline with a device voice.
- **Settings** (gear icon): choose Automatic, Kokoro only, Device voice only, or
  Other API, each shown with whether it's available right now.
- **Where the voice comes from:** while reading, a card shows the voice and its
  source (your Kokoro server, this device, or the API host), and why Automatic
  fell back if it did.
- **Other API + MP3:** OpenAI (`tts-1`, `alloy`) or any HTTPS OpenAI-compatible
  endpoint, generated as an MP3 to play or export.
- Import TXT, Markdown, text-based PDF, and EPUB documents locally.
- Speed control, device pause/resume, and long-text chunking.
- Light/dark themes and an adaptive layout.

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
| Automatic (default) | Kokoro if it answers, else the device voice | Falls back to the device voice, also mid-reading |
| Kokoro only | Kokoro | Shows why (offline, token rejected, not set up) |
| Device voice only | The OS or browser voice | Asks you to install a system voice |
| Other API · MP3 export | OpenAI or your endpoint, as an MP3 | Shows the provider's error |

Each mode shows its availability in Settings. Kokoro's is checked by asking the
server for its voice list, at launch, when Settings opens, on **Check now**, and
before reading (a result under a minute old is reused).

### Kokoro

[Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) is a self-hosted,
OpenAI-compatible neural voice server. Voxen can use the same one Synapse reads
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

### Other API

1. In Settings, choose **Other API · MP3 export** and a provider: OpenAI or
   Custom. Switching provider clears the key, so a key typed for one provider is
   never sent to another.
2. Enter a personal API key, model, and voice. Only use an endpoint you trust
   with that key and your text.
3. Press **Generate MP3**. This sends the text to the provider and may incur
   charges. Long documents require multiple requests.
4. Press **Play MP3** or **Export MP3**.

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

The launcher uses a cyan background (`#009DC4`) and the white Brew cup
with its app-specific symbol. `assets/branding/app_icon.png` is the full-bleed source;
`flutter_launcher_icons.yaml` is the canonical generation configuration.
Android uses an 12% foreground inset to keep the symbol within launcher masks
without a black tile border. Web manifest colors match the icon background.
