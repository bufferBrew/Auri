import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auri/appearance_settings.dart';
import 'package:auri/core/theme/app_theme.dart';
import 'package:auri/main.dart';
import 'package:auri/on_device/local_models.dart';
import 'package:auri/settings_screen.dart';
import 'package:auri/ui/voice_widgets.dart';
import 'package:auri/voice_settings.dart';

VoiceSettings settings({ReadMode mode = ReadMode.auto, http.Client? client}) =>
    VoiceSettings(
      store: MemorySettingsStore(),
      client: client == null ? null : () => client,
    )..mode = mode;

IconButton playButton(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(
    of: find.byIcon(Icons.play_arrow_rounded),
    matching: find.byType(IconButton),
  ),
);

void main() {
  testWidgets('empty reader offers Paste and Import, and play waits for text', (
    tester,
  ) async {
    await tester.pumpWidget(AuriApp(settings: settings()));
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Import document'), findsOneWidget);
    expect(find.text('Device voice'), findsOneWidget);
    expect(find.text('From this device'), findsOneWidget);
    expect(playButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'Hello there.');
    await tester.pump();
    expect(find.text('2 words · about 1 min to listen'), findsOneWidget);
    expect(find.text('Paste'), findsNothing);
    expect(playButton(tester).onPressed, isNotNull);
  });

  testWidgets('Ctrl+Enter starts and pauses reading, with the text shown', (
    tester,
  ) async {
    // A speech engine that accepts every call and is still speaking.
    final speaking = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) => call.method == 'speak' ? speaking.future : Future.value(1),
    );
    await tester.pumpWidget(AuriApp(settings: settings(mode: ReadMode.device)));
    await tester.enterText(
      find.byType(TextField).last,
      'First sentence. Second sentence.',
    );
    Future<void> shortcut() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await shortcut();
    expect(find.text('Reading · 0%'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('Edit'), findsNothing, reason: 'no editing mid-read');

    await shortcut();
    expect(find.byTooltip('Read aloud'), findsOneWidget);
    expect(find.text('Edit'), findsNothing, reason: 'still at the start');
  });

  testWidgets('tapping a paragraph moves speech and reopening resumes it', (
    tester,
  ) async {
    final spoken = <Object?>[];
    final pending = <Completer<Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) {
        if (call.method != 'speak') return Future.value(1);
        spoken.add(call.arguments);
        final result = Completer<Object?>();
        pending.add(result);
        return result.future;
      },
    );
    addTearDown(() {
      for (final result in pending) {
        if (!result.isCompleted) result.complete(1);
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        null,
      );
    });
    final s = settings(mode: ReadMode.device);
    await tester.pumpWidget(AuriApp(settings: s));
    await tester.enterText(find.byType(TextField).first, 'My reading');
    await tester.enterText(
      find.byType(TextField).last,
      'First paragraph.\n\nSecond paragraph.',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(spoken, isNotEmpty);
    await tester.tapAt(
      tester.getTopLeft(find.text('Second paragraph.', findRichText: true)) +
          const Offset(2, 8),
    );
    await tester.pumpAndSettle();
    expect(spoken.last, 'Second paragraph.');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved readings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My reading'));
    await tester.pumpAndSettle();
    expect(find.text('Resumed from your saved place'), findsOneWidget);
    final callsBeforeResume = spoken.length;
    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(spoken, hasLength(callsBeforeResume + 1));
    expect(spoken.last, 'Second paragraph.');
  });

  testWidgets('selected text from another app reads with the device voice', (
    tester,
  ) async {
    final speaking = Completer<Object?>();
    final spoken = <Object?>[];
    tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) {
        if (call.method != 'speak') return Future.value(1);
        spoken.add(call.arguments);
        return speaking.future;
      })
      ..setMockMethodCallHandler(
        const MethodChannel('auri/incoming_text'),
        (call) async => call.method == 'takeText' ? 'Hello from Chrome.' : null,
      );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(const MethodChannel('flutter_tts'), null)
        ..setMockMethodCallHandler(
          const MethodChannel('auri/incoming_text'),
          null,
        );
    });
    // Automatic, with Kokoro set up and answering: it still mustn't be used.
    var kokoroSpeech = 0;
    final s =
        settings(
            client: MockClient((request) async {
              if (request.url.path.endsWith('/speech')) kokoroSpeech++;
              return http.Response('{"voices":["af_heart"]}', 200);
            }),
          )
          ..kokoroUrl = 'https://mac.example.ts.net'
          ..kokoroToken = 'test-placeholder';
    await tester.runAsync(() => s.checkKokoro());
    expect(s.wouldUseKokoro, isTrue);

    await tester.pumpWidget(AuriApp(settings: s));
    await tester.pumpAndSettle();
    expect(find.text('Selected text'), findsOneWidget);
    expect(find.text('Device voice'), findsOneWidget);
    expect(
      find.text('From this device · selected text uses the device voice'),
      findsOneWidget,
    );
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(spoken, isNotEmpty);
    expect(kokoroSpeech, 0);
  });

  testWidgets('the player names Kokoro and its server when it answers', (
    tester,
  ) async {
    final s =
        settings(
            client: MockClient(
              (_) async =>
                  http.Response('{"voices":["af_heart","bf_emma"]}', 200),
            ),
          )
          ..kokoroUrl = 'https://mac.example.ts.net'
          ..kokoroToken = 'test-placeholder';
    await tester.pumpWidget(AuriApp(settings: s));
    await tester.runAsync(() => s.checkKokoro());
    await tester.pump();
    expect(find.text('Kokoro · af_heart'), findsOneWidget);
    expect(find.text('From mac.example.ts.net'), findsOneWidget);
  });

  testWidgets('Other API can export directly once there is text', (
    tester,
  ) async {
    await tester.pumpWidget(AuriApp(settings: settings(mode: ReadMode.api)));
    expect(find.byTooltip('Generate and play'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    final export = tester.widget<MenuItemButton>(
      find.widgetWithText(MenuItemButton, 'Export MP3'),
    );
    expect(export.onPressed, isNull);
    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Export this.');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MenuItemButton>(
            find.widgetWithText(MenuItemButton, 'Export MP3'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the voice sheet switches mode from the player', (tester) async {
    final s = settings();
    await tester.pumpWidget(AuriApp(settings: s));
    await tester.tap(find.text('Device voice'));
    await tester.pumpAndSettle();
    expect(find.text('Voice'), findsOneWidget);
    await tester.tap(find.text('Device voice only'));
    await tester.pumpAndSettle();
    expect(s.mode, ReadMode.device);
  });

  testWidgets('Settings lists every mode with its availability', (
    tester,
  ) async {
    final s = settings();
    await tester.pumpWidget(AuriApp(settings: s));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final modes = find.byType(ReadModePicker);
    for (final mode in ReadMode.values) {
      expect(
        find.descendant(of: modes, matching: find.text(mode.label)),
        findsOneWidget,
      );
    }
    expect(find.text('Not set up'), findsWidgets);
    expect(find.text('Using this device'), findsOneWidget);
    await tester.ensureVisible(find.text('Device voice only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Device voice only'));
    await tester.pumpAndSettle();
    expect(s.mode, ReadMode.device);
    expect(await (s.store as MemorySettingsStore).read('read_mode'), 'device');
  });

  testWidgets('a model downloads only after you agree to its size', (
    tester,
  ) async {
    var requests = 0;
    final local = LocalModels(
      baseDir: () async => Directory.systemTemp,
      client: () => MockClient((_) async {
        requests++;
        return http.Response('stop here', 404);
      }),
    );
    final s = VoiceSettings(store: MemorySettingsStore(), local: local);
    await tester.pumpWidget(AuriApp(settings: s));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final download = find.widgetWithText(OutlinedButton, 'Download').first;
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    expect(find.text('333 MB download'), findsOneWidget);
    expect(find.text('126 MB download'), findsOneWidget);

    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(find.textContaining('This downloads 333 MB'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, 0, reason: 'nothing downloads without a yes');

    await tester.tap(download);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download 333 MB'));
    await tester.pump();
    for (var i = 0; i < 20 && requests == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(requests, 1);
  });

  testWidgets('appearance: dark mode and a colour theme apply and persist', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    await store.write('theme_palette', AppPalette.neon.name);
    final look = AppearanceSettings(store: store);
    await look.load();
    expect(look.palette, AppPalette.neon);
    await tester.pumpWidget(AuriApp(settings: settings(), appearance: look));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Auri colour'));
    await tester.pumpAndSettle();
    expect(look.themeMode, ThemeMode.dark);
    expect(look.palette, AppPalette.auri);
    final colors = Theme.of(
      tester.element(find.byType(SettingsScreen)),
    ).extension<AppColors>()!;
    expect(
      colors.background,
      AppColors.of(AppPalette.auri, Brightness.dark).background,
    );
    final reopened = AppearanceSettings(store: store);
    await reopened.load();
    expect(reopened.themeMode, ThemeMode.dark);
    expect(reopened.palette, AppPalette.auri);
  });

  for (final screen in ['reader', 'settings']) {
    testWidgets('$screen: small screen and 2× text do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = settings();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: screen == 'reader'
                ? ReaderScreen(settings: s)
                : SettingsScreen(
                    settings: s,
                    appearance: AppearanceSettings(
                      store: MemorySettingsStore(),
                    ),
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
