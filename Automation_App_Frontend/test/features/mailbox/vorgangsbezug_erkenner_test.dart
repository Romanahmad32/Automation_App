import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/domain/services/vorgangsbezug_erkenner.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ein Vorgang mit zerlegter Referenz — `zeichen` ergibt sich daraus („144/26
/// C03"), genau wie im Bestand.
Vorgang vorgangMit({
  required String referenz,
  VorgangStatus status = VorgangStatus.beantwortet,
  int? mandantId,
  String? mandantName,
  ZentralrufReplyData? antwort,
}) => Vorgang.ausAnfrage(
  referenz: referenz,
  angefragtAm: DateTime(2026, 9, 1),
  mandantId: mandantId,
  mandantName: mandantName,
).copyWith(status: status, antwort: antwort);

PosteingangEintrag mailMit({
  String betreff = 'Ohne Bezug',
  String absender = 'Fremd <fremd@example.com>',
  String? absenderAdresse,
}) => PosteingangEintrag(
  id: 'm1',
  betreff: betreff,
  absender: absender,
  absenderAdresse: absenderAdresse,
);

void main() {
  final vorgang = vorgangMit(referenz: '144/26 C03_HG-E 1427');

  test('Zeichen im Betreff ist ein sicherer Bezug', () {
    final erkenner = VorgangsbezugErkenner(vorgaenge: [vorgang]);

    final bezug = erkenner.fuer(
      mailMit(betreff: 'AW: Unser Zeichen: 144/26 C03 — Schadenmeldung'),
    );

    expect(bezug!.vorgang.referenz, vorgang.referenz);
    expect(bezug.sicherheit, BezugSicherheit.sicher);
    expect(bezug.grund, 'Zeichen 144/26 C03 steht im Betreff');
  });

  test('Schadennummer im Betreff ist ein sicherer Bezug', () {
    final mitSchaden = vorgangMit(
      referenz: '145/26 C03_HG-E 1428',
      antwort: const ZentralrufReplyData(versicherungsscheinNr: 'SCH-998877'),
    );
    final erkenner = VorgangsbezugErkenner(vorgaenge: [mitSchaden]);

    final bezug = erkenner.fuer(mailMit(betreff: 'Schaden SCH-998877'));

    expect(bezug!.sicherheit, BezugSicherheit.sicher);
    expect(bezug.grund, 'Schadennummer SCH-998877 steht im Betreff');
  });

  test('Zu kurze Schadennummer trifft nicht zufällig', () {
    final kurz = vorgangMit(
      referenz: '146/26 C03_HG-E 1429',
      antwort: const ZentralrufReplyData(versicherungsscheinNr: '12345'),
    );
    final erkenner = VorgangsbezugErkenner(vorgaenge: [kurz]);

    expect(erkenner.fuer(mailMit(betreff: 'Rechnung 12345')), isNull);
  });

  test('Absenderadresse des Mandanten ist ein vermuteter Bezug', () {
    final erkenner = VorgangsbezugErkenner(
      vorgaenge: [
        vorgangMit(
          referenz: '144/26 C03_HG-E 1427',
          mandantId: 7,
          mandantName: 'Erika Muster',
        ),
      ],
      mandantenAdressen: const {7: 'erika@muster.de'},
    );

    final bezug = erkenner.fuer(
      mailMit(betreff: 'Frage', absenderAdresse: 'erika@muster.de'),
    );

    expect(bezug!.sicherheit, BezugSicherheit.vermutet);
    expect(bezug.grund, 'Absender ist der Mandant Erika Muster');
  });

  test('Absenderadresse des Versicherers ist ein vermuteter Bezug', () {
    final erkenner = VorgangsbezugErkenner(
      vorgaenge: [
        vorgangMit(
          referenz: '144/26 C03_HG-E 1427',
          antwort: const ZentralrufReplyData(versichererName: 'HUK-COBURG'),
        ),
      ],
      versichererAdressen: const {'HUK-COBURG': 'schaden@huk.de'},
    );

    final bezug = erkenner.fuer(
      mailMit(betreff: 'Ihre Meldung', absenderAdresse: 'schaden@huk.de'),
    );

    expect(bezug!.sicherheit, BezugSicherheit.vermutet);
    expect(bezug.grund, 'Absender ist der Versicherer HUK-COBURG');
  });

  test('Ohne Anhaltspunkt gibt es keinen Bezug', () {
    final erkenner = VorgangsbezugErkenner(vorgaenge: [vorgang]);

    expect(erkenner.fuer(mailMit(betreff: 'Newsletter September')), isNull);
  });

  test('Zwei Treffer auf derselben Stufe heißen: kein Bezug', () {
    final erkenner = VorgangsbezugErkenner(
      vorgaenge: [
        vorgang,
        vorgangMit(referenz: '145/26 C03_HG-E 1428'),
      ],
    );

    final bezug = erkenner.fuer(
      mailMit(betreff: 'Sammelantwort 144/26 C03 und 145/26 C03'),
    );

    expect(bezug, isNull);
  });

  test('Abgeschlossener Vorgang zählt bei der Adressregel nicht mehr', () {
    final erkenner = VorgangsbezugErkenner(
      vorgaenge: [
        vorgangMit(
          referenz: '144/26 C03_HG-E 1427',
          status: VorgangStatus.versendet,
          mandantId: 7,
          mandantName: 'Erika Muster',
        ),
      ],
      mandantenAdressen: const {7: 'erika@muster.de'},
    );

    expect(erkenner.fuer(mailMit(absenderAdresse: 'erika@muster.de')), isNull);
  });

  test(
    'Schreibweise spielt weder beim Zeichen noch bei der Adresse eine Rolle',
    () {
      final erkenner = VorgangsbezugErkenner(
        vorgaenge: [
          vorgangMit(
            referenz: '144/26 c03_HG-E 1427',
            antwort: const ZentralrufReplyData(versichererName: 'huk-coburg'),
          ),
        ],
        versichererAdressen: const {'HUK-Coburg': 'Schaden@HUK.de'},
      );

      expect(
        erkenner
            .fuer(mailMit(betreff: 'aw: unser zeichen: 144/26 C03'))!
            .sicherheit,
        BezugSicherheit.sicher,
      );
      expect(
        erkenner
            .fuer(
              mailMit(
                betreff: 'Ohne Zeichen',
                absender: 'HUK <SCHADEN@huk.DE>',
              ),
            )!
            .sicherheit,
        BezugSicherheit.vermutet,
      );
    },
  );

  test('Der Erkenner lässt die übergebenen Vorgänge unangetastet', () {
    final bestand = [vorgang];
    final vorher = List<Vorgang>.of(bestand);
    final erkenner = VorgangsbezugErkenner(vorgaenge: bestand);

    erkenner.fuer(mailMit(betreff: 'Unser Zeichen: 144/26 C03'));

    expect(bestand, vorher);
    expect(bestand.single, vorgang);
  });
}
