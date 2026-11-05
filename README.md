# VoiceBrew

A standalone Flutter text-to-speech app for Android and web, extracted from
NeuroBrew without changing or removing NeuroBrew's reader.

- **Device TTS by default:** paste text and press Read aloud. No account, backend,
  API key, or configuration required. Uses the system's default voice/language.
- **API voice + MP3:** choose API voice, enter your own API key, generate audio,
  then play it or export an MP3. Defaults to OpenAI's speech endpoint, `tts-1`,
  and `alloy`. HTTPS OpenAI-compatible endpoints can be configured too.
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

## API speech

1. Choose **API voice · MP3 export**.
2. Enter a personal API key, model, and voice. The full speech endpoint is visible
   and editable. Only use an endpoint you trust with that key and your text.
3. Press **Generate MP3**. This sends the text to the chosen provider and may
   incur charges. Long documents require multiple requests.
4. Press **Play MP3** or **Export MP3**. Export uses the platform save dialog
   or browser download. Regeneration is not needed to export the generated audio.

The API follows the [OpenAI speech contract](https://developers.openai.com/api/reference/resources/audio/subresources/speech/methods/create).
Other providers must implement that contract and return MP3 bytes. Web providers
must permit CORS. Requests use HTTPS, do not follow redirects, and time out after
90 seconds. Cancellation prevents subsequent chunks but cannot undo a provider
request that has already been processed.

## Privacy and security

Keys are entered at runtime and remain in memory only. They are never included
in source, build-time defines, preferences, URLs, logs, or committed files.
No application backend receives your key. This is a personal bring-your-own-key
client: on web, the key is present in your browser memory and outbound request;
never embed a shared production key in a public deployment. For a multi-user
service, put shared provider credentials behind an authenticated server.

Documents and generated audio also remain in memory until explicitly exported.
Closing/reloading the app loses the draft, audio, and key. Device speech is
provided by the OS/browser; some voices use a network service. Install an
appropriate offline voice to read without a connection.

## Limits

- MP3 export requires API speech; device TTS does not produce a portable MP3.
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
