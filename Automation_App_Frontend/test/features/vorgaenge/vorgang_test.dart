import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_json.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vorgang.ausAnfrage', () {
    test('zerlegt die Referenz in ihre Bestandteile', () {
      final vorgang = Vorgang.ausAnfrage(
        referenz: '84/26 C03_GG-XY 123',
        angefragtAm: DateTime(2026, 6, 20),
      );

      expect(vorgang.laufendeNummer, 84);
      expect(vorgang.jahr, '26');
      expect(vorgang.abteilung, 'C03');
      expect(vorgang.kennzeichen, 'GG-XY 123');
      expect(vorgang.status, VorgangStatus.angefragt);
      expect(vorgang.rechtsgebiet, RechtsgebietWert.verkehrsrecht);
      expect(vorgang.aktenzeichen, '84/26 C03');
    });

    test(
      'lässt Bestandteile leer, wenn die Referenz dem Schema nicht folgt',
      () {
        final vorgang = Vorgang.ausAnfrage(
          referenz: 'freitext-referenz',
          angefragtAm: DateTime(2026, 6, 20),
        );

        expect(vorgang.laufendeNummer, isNull);
        expect(vorgang.aktenzeichen, 'freitext-referenz');
      },
    );
  });

  test('toJson/fromJson ist verlustfrei (inkl. Antwort- und Wizard-Daten)', () {
    final original =
        Vorgang.ausAnfrage(
              referenz: '12/26 C03_HG-E 1427',
              angefragtAm: DateTime(2026, 6, 1),
              mandantId: 7,
              mandantName: 'Max Müller',
            )
            .mitAntwort(
              const ZentralrufReplyData(
                referenz: '12/26 C03_HG-E 1427',
                versichererName: 'HUK',
                unfallDatum: '20.06.2026',
                kennzeichen: 'HG-E 1427',
              ),
            )
            .copyWith(
              feldWerte: const {
                'Unfallort': 'Bad Homburg',
                'Mandant': 'Max Müller',
              },
              schadensaufstellung: const DamageListing(
                items: [DamageItem(description: 'Reparatur', amount: 1250.50)],
                gebuehrensatz: 1.3,
                applyVat: true,
                auslagenpauschaleOverride: 20,
              ),
            );

    final kopie = vorgangAusJson(original.toJson());

    expect(kopie, original);
    expect(kopie.status, VorgangStatus.beantwortet);
    expect(kopie.antwort?.versichererName, 'HUK');
    expect(kopie.parteienBezeichnung, 'Max Müller ./. HUK');
    expect(kopie.feldWerte?['Unfallort'], 'Bad Homburg');
    expect(kopie.schadensaufstellung?.items.single.amount, 1250.50);
  });

  test(
    'fromJson übernimmt ein unbekanntes Rechtsgebiet wortgetreu, '
    'nur der Status fällt tolerant zurück',
    () {
      // Seit #70 ist das Rechtsgebiet ein freier String aus dem
      // Sachgebietskatalog: Ein unbekannter gespeicherter Wert bleibt
      // erhalten, statt still auf Verkehrsrecht umgebogen zu werden —
      // genau das Umbiegen hat vorher Bestandszeilen unfilterbar gemacht.
      final vorgang = vorgangAusJson({
        'referenz': '1/26 C03_HG-E 1',
        'angefragtAm': DateTime(2026, 1, 1).toIso8601String(),
        'rechtsgebiet': 'voelkerrecht',
        'status': 'archiviert',
      });

      expect(vorgang.rechtsgebiet, 'voelkerrecht');
      expect(vorgang.status, VorgangStatus.angefragt);
    },
  );
}
