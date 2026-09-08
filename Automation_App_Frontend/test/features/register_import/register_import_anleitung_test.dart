import 'package:automation_app/features/register_import/presentation/utils/register_import_anleitung.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_anleitung_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget anleitungsSeite(int? vorschlag) => MaterialApp(
  home: Scaffold(
    body: RegisterImportAnleitungDialog(vorgeschlagenerJahrgang: vorschlag),
  ),
);

void main() {
  // `Clipboard.setData` hängt im `flutter_tester`: Dort gibt es keinen
  // Zwischenablage-Eigentümer, und der Aufruf über `SystemChannels.platform`
  // wird auf manchen Läufen nie beantwortet — `pumpAndSettle()` läuft dann in
  // seinen eigenen Zehn-Minuten-Zeitrahmen (Befund aus #108).
  TestWidgetsFlutterBinding.ensureInitialized();
  final kopiert = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          kopiert.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });

  setUp(kopiert.clear);

  test('der Auftrag trägt den gewählten Jahrgang statt des Platzhalters', () {
    final text = RegisterImportAnleitung.textFuer(2021);

    expect(text, contains('2021'));
    expect(text, isNot(contains(RegisterImportAnleitung.jahrgangsPlatzhalter)));
    expect(text, contains('"version": 1'));
    expect(text, contains('"laufendeNummer"'));
    expect(
      text,
      contains('freitext'),
      reason: 'der Wortlaut der Zelle ist der Beleg und gehört in den Auftrag',
    );
  });

  test('der Dateiaufbau steht nur einmal da', () {
    expect(
      RegisterImportAnleitung.textFuer(2020),
      contains(
        RegisterImportAnleitung.dateiaufbau
            .replaceAll(RegisterImportAnleitung.jahrgangsPlatzhalter, '2020')
            .trim(),
      ),
    );
  });

  testWidgets('der Vorschlag steht voreingestellt im Auftrag', (tester) async {
    await tester.pumpWidget(anleitungsSeite(2019));
    await tester.pumpAndSettle();

    expect(find.text('2019'), findsWidgets);
    expect(find.textContaining('Jahrgang 2019'), findsWidgets);
  });

  testWidgets('ohne Vorschlag steht das laufende Jahr minus eins', (
    tester,
  ) async {
    await tester.pumpWidget(anleitungsSeite(null));
    await tester.pumpAndSettle();

    expect(find.text('${DateTime.now().year - 1}'), findsWidgets);
  });

  testWidgets('der Kopieren-Knopf legt den Auftrag des Jahrgangs ab', (
    tester,
  ) async {
    await tester.pumpWidget(anleitungsSeite(2019));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auftrag kopieren'));
    await tester.pump();

    expect(kopiert, hasLength(1));
    expect(kopiert.single, contains('2019'));
    expect(
      kopiert.single,
      isNot(contains(RegisterImportAnleitung.jahrgangsPlatzhalter)),
    );
  });
}
