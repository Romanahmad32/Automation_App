import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_leerzustand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Leerzustand einer neuen Vorlage (#104, Stufe 3b): „Womit fängt diese
/// Vorlage an?"
///
/// Geprüft wird vor allem die Gleichwertigkeit der beiden Word-Dateien — beide
/// Wahlflächen gleich groß, beide mit demselben Knopf — und dass auf einem
/// schmalen Fenster nichts überläuft (Issue #57).
void main() {
  late List<TemplateFileSlot> gewaehlt;

  setUp(() => gewaehlt = []);

  Future<void> zeige(WidgetTester tester, double breite) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: breite,
              child: VorlagenLeerzustand(onDateiWaehlen: gewaehlt.add),
            ),
          ),
        ),
      ),
    );
  }

  /// Der Knopf **in** einer der beiden Flächen — beide tragen dieselbe
  /// Aufschrift, auseinanderzuhalten sind sie nur über den Schlüssel ihrer
  /// Fläche.
  Finder knopfIn(TemplateFileSlot slot) => find.descendant(
    of: find.byKey(ValueKey(slot)),
    matching: find.byType(CustomRectangularButton),
  );

  testWidgets('beide Wahlflächen führen zu ihrem eigenen Slot', (tester) async {
    await zeige(tester, 900);

    expect(find.text('Womit fängt diese Vorlage an?'), findsOneWidget);
    expect(find.text('Ohne Schadensaufstellung'), findsOneWidget);
    expect(find.text('Mit Schadensaufstellung'), findsOneWidget);
    // Derselbe Knopf an beiden Flächen — keine ist die zweite oder optionale.
    expect(find.text('Datei wählen…'), findsNWidgets(2));

    await tester.tap(knopfIn(TemplateFileSlot.ohneAuflistung));
    await tester.tap(knopfIn(TemplateFileSlot.mitAuflistung));

    expect(gewaehlt, [
      TemplateFileSlot.ohneAuflistung,
      TemplateFileSlot.mitAuflistung,
    ]);
  });

  testWidgets('nebeneinander sind beide Flächen gleich groß', (tester) async {
    // Die beiden Word-Dateien sind gleichwertig; eine größere Fläche läse sich
    // als „die richtige".
    await zeige(tester, 900);

    final ohne = tester.getSize(
      find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
    );
    final mit = tester.getSize(
      find.byKey(const ValueKey(TemplateFileSlot.mitAuflistung)),
    );

    expect(ohne, mit);
  });

  testWidgets('beide Flächen erklären, wofür ihre Datei da ist', (
    tester,
  ) async {
    await zeige(tester, 900);

    expect(find.text('Anspruchsschreiben ohne Positionsliste'), findsOneWidget);
    expect(
      find.text('Anspruchsschreiben mit {{Schadensaufstellung}}-Tabelle'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Eine der beiden Dateien genügt.'),
      findsOneWidget,
    );
  });

  testWidgets('auf 500 px läuft nichts über — die Flächen stapeln sich', (
    tester,
  ) async {
    await zeige(tester, 500);

    // Ein Überlauf liesse den Test schon beim Aufbau fallen; hier steht die
    // Gegenprobe, dass die Flächen wirklich untereinander liegen und beide
    // bedienbar bleiben.
    final ohne = tester.getTopLeft(
      find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
    );
    final mit = tester.getTopLeft(
      find.byKey(const ValueKey(TemplateFileSlot.mitAuflistung)),
    );
    expect(mit.dy, greaterThan(ohne.dy));
    expect(mit.dx, ohne.dx);

    await tester.tap(knopfIn(TemplateFileSlot.mitAuflistung));
    expect(gewaehlt, [TemplateFileSlot.mitAuflistung]);
  });

  testWidgets('das Klickziel ist mindestens 32 px hoch', (tester) async {
    await zeige(tester, 900);

    final knopf = tester.getSize(knopfIn(TemplateFileSlot.ohneAuflistung));
    expect(knopf.height, greaterThanOrEqualTo(32));
  });
}
