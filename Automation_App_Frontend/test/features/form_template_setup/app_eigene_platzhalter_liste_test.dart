import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/app_eigene_platzhalter_liste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die RVG-Werte waren längst da — nur wusste es niemand: `{{RvgBrutto}}`
/// errät man nicht (#31). Diese Liste ist die Antwort darauf, und sie taugt
/// nur, wenn sie **vollständig** ist: Ein Name, der in der Vorlage wirkt, aber
/// hier fehlt, ist genauso unauffindbar wie vorher.
///
/// Dass die Namen zum Backend passen, prüft `app_eigene_platzhalter_test.dart`
/// gegen die Quelle. Hier geht es darum, dass sie den Anwalt auch erreichen.
void main() {
  Future<void> zeige(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AppEigenePlatzhalterListe()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Zugeklappt ist der Ausgangszustand: Nachschlagen, keine Aufgabe.
  testWidgets('steht zugeklappt da und nennt nur ihren Zweck', (tester) async {
    await zeige(tester);

    expect(find.text('Diese Platzhalter füllt die App selbst'), findsOneWidget);
    expect(find.text('{{RvgBrutto}}'), findsNothing);
  });

  testWidgets('aufgeklappt steht jeder Platzhalter mit Klammern da', (
    tester,
  ) async {
    await zeige(tester);
    await tester.tap(find.text('Diese Platzhalter füllt die App selbst'));
    await tester.pumpAndSettle();

    for (final eintrag in AppEigenePlatzhalter.eintraege) {
      expect(
        find.text('{{${eintrag.name}}}'),
        findsOneWidget,
        reason: '${eintrag.name} fehlt in der Liste',
      );
    }
  });

  /// Die Beispielausgabe ist der Grund, warum die Liste mehr ist als eine
  /// Aufzählung: Sie sagt, was im Brief steht — und nennt die Rechnung dazu,
  /// damit die Zahlen nachvollziehbar zueinander passen.
  testWidgets('zeigt zu jedem Namen die Beispielausgabe', (tester) async {
    await zeige(tester);
    await tester.tap(find.text('Diese Platzhalter füllt die App selbst'));
    await tester.pumpAndSettle();

    expect(find.text(AppEigenePlatzhalter.beispiel), findsOneWidget);
    expect(find.text('4.822,21'), findsOneWidget);
    expect(find.text('1,3'), findsOneWidget);
  });
}
