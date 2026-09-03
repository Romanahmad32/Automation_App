import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_vollstaendigkeit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vollstaendigeAntwort = ZentralrufReplyData(
    versichererName: 'HUK-COBURG',
    versichererStrasse: 'Lyoner Str. 10',
    versichererPlz: '60524',
    versichererOrt: 'Frankfurt',
    unfallDatum: '09.03.2026',
  );

  Vorgang vollstaendig() => Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    status: VorgangStatus.beantwortet,
    mandantId: 7,
    mandantName: 'Erika Mustermann',
    unfallDatum: '09.03.2026',
    unfallort: 'Bad Homburg',
    geschaedigtenKennzeichen: 'HG-E 1427',
    antwort: vollstaendigeAntwort,
  );

  test('meldet nichts bei vollständigem Vorgang', () {
    expect(
      VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vollstaendig()),
      isEmpty,
    );
  });

  test('listet fehlende Unfall- und Mandantendaten', () {
    final vorgang = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 4, 8),
    );

    final fehlt = VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang);

    expect(fehlt, [
      'Mandant',
      'Unfalldatum',
      'Unfallort',
      'Kennzeichen des Mandanten',
    ]);
  });

  test('Unfalldatum aus der Antwort genügt', () {
    final vorgang = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 4, 8),
      status: VorgangStatus.beantwortet,
      mandantName: 'Erika Mustermann',
      unfallort: 'Bad Homburg',
      geschaedigtenKennzeichen: 'HG-E 1427',
      antwort: vollstaendigeAntwort,
    );

    expect(
      VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang),
      isEmpty,
    );
  });

  test('meldet Negativ-Antwort als fehlenden Versicherer', () {
    final vorgang = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 4, 8),
      status: VorgangStatus.beantwortet,
      mandantName: 'Erika Mustermann',
      unfallDatum: '09.03.2026',
      unfallort: 'Bad Homburg',
      geschaedigtenKennzeichen: 'HG-E 1427',
      antwort: const ZentralrufReplyData(keinVersichererErmittelt: true),
    );

    expect(
      VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang),
      contains('Gegnerischer Versicherer'),
    );
  });

  test('meldet unvollständige Versichereranschrift', () {
    final vorgang = vollstaendig().copyWith(
      antwort: const ZentralrufReplyData(
        versichererName: 'HUK-COBURG',
        unfallDatum: '09.03.2026',
      ),
    );

    expect(VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang), [
      'Anschrift des Versicherers',
    ]);
  });

  test('bei anderen Rechtsgebieten zählen nur die Mandantendaten', () {
    final vorgang = Vorgang(
      referenz: '12/26 C03_STRAF',
      angefragtAm: DateTime(2026, 4, 8),
      rechtsgebiet: 'Strafrecht',
    );

    expect(VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang), [
      'Mandant',
    ]);
  });

  test('versendete Vorgänge melden nichts mehr', () {
    final vorgang = Vorgang(
      referenz: '84/26 C03_GG-XY 123',
      angefragtAm: DateTime(2026, 4, 8),
      status: VorgangStatus.versendet,
    );

    expect(
      VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang),
      isEmpty,
    );
  });
}
