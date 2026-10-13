import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_senden_bestaetigung.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_overview.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_art_auswahl.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog_knoepfe.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_aktionsleiste.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Keys, über die ein Suchfeld, ein Menüeintrag oder ein Umschalter ansprechbar
/// ist — auch leer und auch, wo derselbe Text mehrfach vorkommt.
void main() {
  Future<void> zeige(WidgetTester tester, Widget kind) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: kind)));

  testWidgets('die Suchleiste trägt den Key auf dem Textfeld', (tester) async {
    await zeige(
      tester,
      EntitySearchBar(
        feldSchluessel: MandantenOverview.sucheSchluessel,
        initialQuery: '',
        hintText: 'Suchen',
        onChanged: (_) {},
      ),
    );

    final feld = find.byKey(const ValueKey('mandanten-suche'));
    expect(tester.widget(feld), isA<TextField>());
  });

  testWidgets('Menüeinträge tragen ihren Key, das Feld auch', (tester) async {
    await zeige(
      tester,
      SearchableDropdown<String>(
        feldSchluessel: const ValueKey('vorgang-auswahl'),
        value: null,
        onChanged: (_) {},
        entries: const [
          SearchableDropdownEntry(
            value: 'a',
            label: 'Eintrag A',
            schluessel: ValueKey('vorgang-auswahl-a'),
          ),
          SearchableDropdownEntry(value: 'b', label: 'Eintrag B'),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('vorgang-auswahl')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vorgang-auswahl')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vorgang-auswahl-a')), findsOneWidget);
    expect(find.text('Eintrag B'), findsOneWidget);
  });

  testWidgets('die Vollmacht-Arten sind einzeln ansprechbar', (tester) async {
    await zeige(
      tester,
      VollmachtArtAuswahl(art: null, rechtsgebiet: '', onGewaehlt: (_) {}),
    );

    for (final name in ['unfallsachen', 'bussgeldsachen', 'strafsache']) {
      expect(
        find.byKey(ValueKey('vollmacht-art-$name')),
        findsOneWidget,
        reason: name,
      );
    }
    expect(
      VollmachtArtAuswahl.schluessel(VollmachtArt.strafsache),
      const ValueKey('vollmacht-art-strafsache'),
    );
  });

  test('die drei Knöpfe mit Außenwirkung tragen die gesperrten Namen', () {
    // Die Marionette-Sperre greift auf genau diese Namen; ändert sich einer,
    // wäre der Knopf ohne Sperre bedienbar.
    expect(
      VorgangAktionsleiste.zentralrufSchluessel,
      const ValueKey('zentralruf-formular-ausfuellen'),
    );
    expect(
      EmailSendenBestaetigung.sendenSchluessel,
      const ValueKey('versand-senden'),
    );
    expect(
      VollmachtDialogKnoepfe.druckenSchluessel,
      const ValueKey('vollmacht-drucken'),
    );
  });
}
