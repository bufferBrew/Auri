import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voxen/main.dart';
import 'package:voxen/voice_settings.dart';

VoiceSettings settings({ReadMode mode = ReadMode.auto, http.Client? client}) =>
    VoiceSettings(
      store: MemorySettingsStore(),
      client: client == null ? null : () => client,
    )..mode = mode;

Future<void> scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('Automatic without Kokoro reads with the device voice', (
    tester,
  ) async {
    await tester.pumpWidget(VoxenApp(settings: settings()));
    expect(find.text('Will read with · Automatic'), findsOneWidget);
    expect(find.text('Device voice · system default'), findsOneWidget);
    expect(find.text('From this device'), findsOneWidget);
    expect(find.text('API key'), findsNothing);
    await scrollTo(tester, find.text('Read aloud'));
    await tester.ensureVisible(find.text('Read aloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read aloud'));
    await tester.pump();
    await scrollTo(tester, find.text('Paste or import some text first.'));
    expect(find.text('Paste or import some text first.'), findsOneWidget);
  });

  testWidgets('Automatic shows Kokoro and its server when it answers', (
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
    await tester.pumpWidget(VoxenApp(settings: s));
    await tester.runAsync(() => s.checkKokoro());
    await tester.pump();
    expect(find.text('Kokoro · af_heart'), findsOneWidget);
    expect(
      find.text('From your Kokoro server, mac.example.ts.net'),
      findsOneWidget,
    );
  });

  testWidgets('Other API mode keeps Generate, and export waits for audio', (
    tester,
  ) async {
    await tester.pumpWidget(VoxenApp(settings: settings(mode: ReadMode.api)));
    await scrollTo(tester, find.text('Export MP3'));
    expect(find.text('Read aloud'), findsNothing);
    final export = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export MP3'),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('Settings lists every mode with its availability', (
    tester,
  ) async {
    final s = settings();
    await tester.pumpWidget(VoxenApp(settings: s));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    for (final mode in ReadMode.values) {
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(
      find.text('Kokoro · Not set up: add the server address'),
      findsOneWidget,
    );
    expect(
      find.text('This device · Available · system default voice'),
      findsOneWidget,
    );
    await tester.tap(find.text('Device voice only'));
    await tester.pumpAndSettle();
    expect(s.mode, ReadMode.device);
    expect(await (s.store as MemorySettingsStore).read('read_mode'), 'device');
  });

  testWidgets('small screen and enlarged text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ReaderScreen(settings: settings()),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
