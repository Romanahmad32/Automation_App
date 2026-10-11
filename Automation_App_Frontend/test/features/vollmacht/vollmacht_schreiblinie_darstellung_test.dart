import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_kopf_felder.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_dialog_testaufbau.dart';
import 'vollmacht_doubles.dart';

/// Was der Dialog über leere Felder sagt (§4.11, #171): ein Hinweis unter
/// jedem Feld, das auf dem Papier als Linie frei bleibt, eine Zeile darüber
/// direkt über den Knöpfen — und nur die Felder, die auf der Vorlage stehen.
/// Alles bei „Am größten" ohne Überlauf.
void main() {
  const freiHinweis = VollmachtKopfFelder.freiHinweis;
  const heutige = VollmachtRepositoryDouble.heutigePlatzhalter;

  /// Ein Mandant ohne Straße und Telefon.
  final mandant = Mandant(
    id: 7,
    vorname: 'Max',
    nachname: 'Probe',
    postleitzahl: '12345',
    ort: 'Musterstadt',
    emailAdresse: 'max@example.org',
    erstelltAm: DateTime(2026),
  );

  /// Ein Vorgang der Abteilung [abteilung] — die Art leitet sich daraus ab,
  /// der Katalog bleibt leer.
  Future<VollmachtCubit> baue(
    WidgetTester tester, {
    required String abteilung,
    Map<VollmachtArt, List<String>>? platzhalter = heutige,
    String? unfallDatum,
    bool drucken = false,
    bool inWordOeffnen = false,
  }) => baueVollmachtDialogCubit(
    tester,
    vorgang: Vorgang(
      referenz: '12/26 ${abteilung}_GG-XY 1',
      angefragtAm: DateTime(2026, 9, 1),
      abteilung: abteilung,
      unfallDatum: unfallDatum,
      mandantId: 7,
    ),
    mandant: mandant,
    platzhalter: platzhalter,
    drucken: drucken,
    inWordOeffnen: inWordOeffnen,
  );

  Future<void> zeigeDialog(
    WidgetTester tester,
    VollmachtCubit cubit, {
    Size fenster = const Size(1400, 1000),
  }) => zeigeVollmachtDialog(tester, cubit, fenster: fenster);

  Finder feld(String schluessel) =>
      find.byKey(ValueKey('vollmacht-$schluessel'), skipOffstage: false);

  Finder hinweisUnter(String schluessel) => find.descendant(
    of: feld(schluessel),
    matching: find.text(freiHinweis, skipOffstage: false),
  );

  String text(WidgetTester tester, String schluessel) => tester
      .widget<EditableText>(
        find.descendant(
          of: feld(schluessel),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  testWidgets('Unfallsachen: Hinweis unter jedem leeren Feld, Zeile über den '
      'Knöpfen, Drucken bleibt möglich', (tester) async {
    final cubit = await baue(
      tester,
      abteilung: 'C03',
      unfallDatum: '02.08.2026',
    );

    await zeigeDialog(tester, cubit);

    expect(tester.takeException(), isNull);
    expect(hinweisUnter('strasse'), findsOneWidget);
    expect(hinweisUnter('telefon'), findsOneWidget);
    for (final gefuellt in ['vorname', 'nachname', 'plz', 'ort', 'email']) {
      expect(hinweisUnter(gefuellt), findsNothing, reason: gefuellt);
    }
    expect(hinweisUnter('unfalldatum'), findsNothing);
    expect(hinweisUnter('inSachen'), findsNothing, reason: 'nie bei in Sachen');
    expect(
      find.text(
        'Auf dem Papier frei zum Ausfüllen: Straße und Hausnummer, Telefon',
      ),
      findsOneWidget,
    );
    final drucken = find.widgetWithText(FilledButton, 'Drucken');
    expect(tester.widget<FilledButton>(drucken).onPressed, isNotNull);
  });

  testWidgets(
    'die Zeile steht unter der Word-Leiste, direkt über den Knöpfen',
    (tester) async {
      final cubit = await baue(tester, abteilung: 'C05', inWordOeffnen: true);

      await zeigeDialog(tester, cubit);

      expect(tester.takeException(), isNull);
      final zeile = tester.getTopLeft(
        find.textContaining('Auf dem Papier frei zum Ausfüllen'),
      );
      final leiste = tester.getTopLeft(find.text('Als gedruckt vermerken'));
      final knopf = tester.getTopLeft(find.text('Schließen'));
      expect(zeile.dy, greaterThan(leiste.dy));
      expect(zeile.dy, lessThan(knopf.dy));
    },
  );

  testWidgets('Strafsache mit den heutigen Vorlagen: kein Telefon, keine '
      'E-Mail', (tester) async {
    final cubit = await baue(tester, abteilung: 'C05');

    await zeigeDialog(tester, cubit);

    expect(feld('telefon'), findsNothing);
    expect(feld('email'), findsNothing);
    expect(feld('unfalldatum'), findsNothing);
    expect(feld('tatdatum'), findsNothing);
    expect(
      find.text('Auf dem Papier frei zum Ausfüllen: Straße und Hausnummer'),
      findsOneWidget,
      reason: 'Das fehlende Telefon druckt diese Vorlage gar nicht.',
    );
  });

  testWidgets('unbekannter Vorlagenstand: alle Felder wie bisher, Schlüssel '
      'unverändert', (tester) async {
    final cubit = await baue(tester, abteilung: 'C03', platzhalter: null);

    await zeigeDialog(tester, cubit);

    for (final schluessel in [
      'vorname',
      'nachname',
      'strasse',
      'plz',
      'ort',
      'telefon',
      'email',
      'unfalldatum',
      'inSachen',
      'wegen',
    ]) {
      expect(feld(schluessel), findsOneWidget, reason: schluessel);
    }
    expect(feld('tatdatum'), findsNothing);
  });

  testWidgets('Bußgeldsachen: eigenes Tatdatum, „wegen" zieht nach', (
    tester,
  ) async {
    final cubit = await baue(tester, abteilung: 'C03o');
    await zeigeDialog(tester, cubit);

    expect(text(tester, 'wegen'), 'Vorwurf der OWi. am ${'_' * 12}');
    expect(hinweisUnter('tatdatum'), findsOneWidget);
    expect(
      find.text(
        'Auf dem Papier frei zum Ausfüllen: Straße und Hausnummer, Tatdatum',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Das Tatdatum kennt die App nicht'),
      findsNothing,
    );

    await tester.enterText(feld('tatdatum'), '03.10.2026');
    await tester.pump();

    expect(text(tester, 'wegen'), 'Vorwurf der OWi. am 03.10.2026');
    expect(hinweisUnter('tatdatum'), findsNothing);
    expect(
      find.text('Auf dem Papier frei zum Ausfüllen: Straße und Hausnummer'),
      findsOneWidget,
    );
    expect(cubit.state.auftrag!.toJson().containsKey('tatdatum'), isFalse);
  });

  testWidgets('ein von Hand geschriebenes „wegen": das leere Datum speist '
      'nichts mehr', (tester) async {
    final cubit = await baue(tester, abteilung: 'C03o');
    await zeigeDialog(tester, cubit);

    await tester.enterText(feld('wegen'), 'Vorwurf der OWi. vom Mai');
    await tester.pump();

    expect(hinweisUnter('tatdatum'), findsNothing);
    expect(find.textContaining(', Tatdatum'), findsNothing);
  });

  testWidgets('im Ergebnis keine Zeile', (tester) async {
    final cubit = await baue(tester, abteilung: 'C05', drucken: true);

    await zeigeDialog(tester, cubit);

    expect(find.text('Fertig'), findsOneWidget);
    expect(find.textContaining('Auf dem Papier frei'), findsNothing);
  });

  for (final (name, fenster) in [
    ('breites Fenster', const Size(1400, 1000)),
    ('schmales Fenster', const Size(800, 900)),
    ('niedriges Fenster', const Size(1200, 700)),
  ]) {
    testWidgets('$name bei „Am größten": ohne Mandant, mit Word-Leiste — '
        'nichts läuft über', (tester) async {
      final cubit = await baue(
        tester,
        abteilung: 'C03',
        platzhalter: null,
        inWordOeffnen: true,
      );
      // Alle Mandantenfelder leer: der meiste Hinweistext, den es gibt.
      cubit.aendereKopfdaten(
        cubit.state.kopfdaten.copyWith(
          vorname: '',
          nachname: '',
          plz: '',
          ort: '',
          email: '',
        ),
      );

      await zeigeDialog(tester, cubit, fenster: fenster);

      expect(tester.takeException(), isNull);
      expect(hinweisUnter('plz'), findsOneWidget);
      expect(
        find.textContaining('Auf dem Papier frei zum Ausfüllen: Vorname,'),
        findsOneWidget,
      );
      expect(find.text('Schließen'), findsOneWidget);
    });
  }
}
