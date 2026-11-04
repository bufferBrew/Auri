import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicebrew/main.dart';

void main() {
  testWidgets('defaults to device TTS with no credentials required', (
    tester,
  ) async {
    await tester.pumpWidget(const VoiceBrewApp());
    expect(find.text('Device TTS · default'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Read aloud'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Read aloud'), findsOneWidget);
    expect(find.text('API key'), findsNothing);
    await tester.ensureVisible(find.text('Read aloud'));
    await tester.tap(find.text('Read aloud'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Paste or import some text first.'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paste or import some text first.'), findsOneWidget);
  });
  testWidgets('API mode exposes key and export, disabled before generation', (
    tester,
  ) async {
    await tester.pumpWidget(const VoiceBrewApp());
    await tester.tap(find.byType(DropdownButtonFormField<SpeechMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API voice · MP3 export').last);
    await tester.pumpAndSettle();
    expect(find.text('API key'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Export MP3'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final export = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export MP3'),
    );
    expect(export.onPressed, isNull);
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
          child: const ReaderScreen(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
