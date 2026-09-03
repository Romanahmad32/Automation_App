import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/datums_vorbelegung_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Einsteller der Datums-Vorbelegung (§5.3). Geprüft wird, was der Anwalt
/// sieht: die abgeleiteten Werte samt Hinweis, solange nichts eingestellt ist,
/// und das Datum, das dabei herauskommt.
void main() {
  /// Der Aufrufer hält den Stand wie die Detailseite: Was gemeldet wird, kommt
  /// beim nächsten Aufbau wieder herein. Ohne das prüfte der Test einen
  /// Zustand, den es in der App nicht gibt.
  Future<List<DatumsVorbelegung?>> zeige(
    WidgetTester tester, {
    required String feldname,
    DatumsVorbelegung? start,
  }) async {
    final gemeldet = <DatumsVorbelegung?>[];
    var stand = start;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DatumsVorbelegungEditor(
              vorbelegung: stand,
              feldname: feldname,
              onChanged: (wert) => setState(() {
                stand = wert;
                gemeldet.add(wert);
              }),
            ),
          ),
        ),
      ),
    );
    return gemeldet;
  }

  /// Das Eingabefeld hinter einem Beschriftungstext.
  Finder feldMit(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  String textVon(Finder feld) =>
      (feld.evaluate().single.widget as TextField).controller!.text;

  /// Die Vorschauzeile rechnet mit `DateTime.now()`. Läuft der Test über
  /// Mitternacht, ist auch das Datum von morgen richtig — beide zulassen,
  /// statt den Test einmal im Jahr rot werden zu lassen.
  void erwarteVorschau(DatumsVorbelegung vorbelegung) {
    final heute = DateTime.now();
    final erlaubt = {
      deutschesDatum(vorbelegung.anwendenAuf(heute)),
      deutschesDatum(
        vorbelegung.anwendenAuf(heute.add(const Duration(days: 1))),
      ),
    };
    final treffer = erlaubt.where(
      (datum) =>
          find.textContaining('ergibt heute: $datum').evaluate().isNotEmpty,
    );

    expect(
      treffer,
      isNotEmpty,
      reason: 'keine Vorschauzeile mit einem von $erlaubt gefunden',
    );
  }

  testWidgets(
    'ohne Einstellung stehen die abgeleiteten Werte samt Hinweis da',
    (tester) async {
      await zeige(tester, feldname: 'Zahlungsfrist');

      expect(textVon(feldMit('Wochen')), '5');
      expect(textVon(feldMit('Jahre')), '0');
      expect(
        find.textContaining('aus dem Feldnamen abgeleitet'),
        findsOneWidget,
      );
      erwarteVorschau(const DatumsVorbelegung(wochen: 5));
    },
  );

  testWidgets('eine Eingabe in „Wochen" meldet den vollen Stand', (
    tester,
  ) async {
    final gemeldet = await zeige(tester, feldname: 'Unfalldatum');

    await tester.enterText(feldMit('Wochen'), '3');
    await tester.pump();

    expect(gemeldet.last, const DatumsVorbelegung(wochen: 3));
    erwarteVorschau(const DatumsVorbelegung(wochen: 3));
    // Ab jetzt ist es eine feste Einstellung, nicht mehr eine Ableitung.
    expect(find.textContaining('aus dem Feldnamen abgeleitet'), findsNothing);
  });

  testWidgets('lauter Nullen werden ausdrücklich gemeldet', (tester) async {
    // Der Weg, die Namensregel abzuschalten: Der Anwalt stellt 0 ein, und der
    // Aufrufer bekommt eine Vorbelegung „heute" statt null.
    final gemeldet = await zeige(tester, feldname: 'Zahlungsfrist');

    await tester.enterText(feldMit('Wochen'), '0');
    await tester.pump();

    expect(gemeldet.last, isNotNull);
    expect(gemeldet.last!.istHeute, isTrue);
    erwarteVorschau(const DatumsVorbelegung());
  });

  testWidgets('eine eingestellte Vorbelegung schlägt die Ableitung', (
    tester,
  ) async {
    await zeige(
      tester,
      feldname: 'Zahlungsfrist',
      start: const DatumsVorbelegung(jahre: 1, tage: 4),
    );

    expect(textVon(feldMit('Jahre')), '1');
    expect(textVon(feldMit('Tage')), '4');
    expect(textVon(feldMit('Wochen')), '0');
    expect(find.textContaining('aus dem Feldnamen abgeleitet'), findsNothing);
    erwarteVorschau(const DatumsVorbelegung(jahre: 1, tage: 4));
  });

  testWidgets('ein anderer Feldname zieht die Ableitung nach', (tester) async {
    // Auf der Detailseite tippt der Anwalt den Feldnamen, während der
    // Einsteller darunter steht — die abgeleiteten Werte müssen mitgehen.
    await zeige(tester, feldname: 'Unfalldatum');
    expect(textVon(feldMit('Wochen')), '0');

    await zeige(tester, feldname: 'Frist');

    expect(textVon(feldMit('Wochen')), '4');
    erwarteVorschau(const DatumsVorbelegung(wochen: 4));
  });
}
