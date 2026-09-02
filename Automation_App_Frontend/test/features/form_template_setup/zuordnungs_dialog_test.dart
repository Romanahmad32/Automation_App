import 'package:automation_app/features/form_template_setup/presentation/widgets/zuordnungs_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Zuordnung von Feldname und Platzhalter (#36): Wer keinen Partner hat,
/// bekommt einen angeboten — und wer schon einen hat, wird nicht dafür
/// ausgeschlachtet.
void main() {
  ZuordnungsWahl? wahl;

  setUp(() => wahl = null);

  /// Baut eine Seite mit einem Knopf, der [aktion] mit einem echten
  /// [BuildContext] ruft — anders lässt sich `showDialog` nicht auslösen.
  Future<void> zeigeKnopf(
    WidgetTester tester,
    Future<void> Function(BuildContext context) aktion,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => aktion(context),
              child: const Text('los'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
  }

  Future<void> fuerPlatzhalter(
    WidgetTester tester, {
    required String platzhalter,
    required List<String?> feldnamen,
    required List<String> allePlatzhalter,
  }) {
    return zeigeKnopf(tester, (context) async {
      wahl = await ZuordnungsDialog.fuerPlatzhalter(
        context,
        platzhalter: platzhalter,
        feldnamen: feldnamen,
        allePlatzhalter: allePlatzhalter,
      );
    });
  }

  testWidgets('ohne Kandidaten wird nicht gefragt — der Chip legt wie bisher '
      'ein Feld an', (tester) async {
    await fuerPlatzhalter(
      tester,
      platzhalter: 'Zeichen',
      feldnamen: const ['Mandant'],
      allePlatzhalter: const ['Zeichen', 'Mandant'],
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(wahl, isA<NeuesFeldAnlegen>());
  });

  testWidgets('ein ähnliches Feld wird zum Umbenennen angeboten', (
    tester,
  ) async {
    await fuerPlatzhalter(
      tester,
      platzhalter: 'Verkehrsunfalldatum',
      feldnamen: const ['Unfalldatum', 'Mandant'],
      allePlatzhalter: const ['Verkehrsunfalldatum'],
    );
    expect(find.text('Platzhalter {{Verkehrsunfalldatum}} zuordnen'), findsOne);

    await tester.tap(find.text('Unfalldatum'));
    await tester.pumpAndSettle();

    expect(wahl, isA<NamenUebernehmen>());
    expect((wahl! as NamenUebernehmen).name, 'Unfalldatum');
  });

  testWidgets('wer den Vorschlag ausschlägt, bekommt sein neues Feld', (
    tester,
  ) async {
    await fuerPlatzhalter(
      tester,
      platzhalter: 'Verkehrsunfalldatum',
      feldnamen: const ['Unfalldatum'],
      allePlatzhalter: const ['Verkehrsunfalldatum'],
    );

    await tester.tap(find.text('Neues Feld anlegen'));
    await tester.pumpAndSettle();

    expect(wahl, isA<NeuesFeldAnlegen>());
  });

  testWidgets('ein Feld, das schon in einer Word-Datei ankommt, steht als '
      'Befund da und ist nicht anklickbar', (tester) async {
    await fuerPlatzhalter(
      tester,
      platzhalter: 'Verkehrsunfalldatum',
      feldnamen: const ['Unfalldatum'],
      // Die Auflistungs-Datei nennt dieselbe Angabe anders — das Feld
      // "Unfalldatum" kommt dort an. Es umzubenennen tauschte nur den einen
      // Waisen gegen den anderen.
      allePlatzhalter: const ['Verkehrsunfalldatum', 'Unfalldatum'],
    );

    expect(find.textContaining('Nicht umbenennen: Unfalldatum'), findsOne);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('abbrechen heißt: nichts passiert', (tester) async {
    await fuerPlatzhalter(
      tester,
      platzhalter: 'Verkehrsunfalldatum',
      feldnamen: const ['Unfalldatum'],
      allePlatzhalter: const ['Verkehrsunfalldatum'],
    );

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(wahl, isNull);
  });

  testWidgets('das Feld ohne Platzhalter wählt umgekehrt aus den offenen — '
      'auch von Hand, wenn keine Regel greift', (tester) async {
    await zeigeKnopf(tester, (context) async {
      wahl = await ZuordnungsDialog.fuerFeld(
        context,
        feldname: 'VersScheinNr',
        offenePlatzhalter: const ['Frist', 'Versicherungsschein-Nr'],
      );
    });
    expect(find.text('Feld "VersScheinNr" zuordnen'), findsOne);

    // Keine Regel erkennt die beiden als verwandt; der Mensch schon.
    await tester.tap(find.text('Anderen Namen wählen (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Versicherungsschein-Nr'));
    await tester.pumpAndSettle();

    expect((wahl! as NamenUebernehmen).name, 'Versicherungsschein-Nr');
  });
}
