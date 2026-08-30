import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime jetzt = DateTime(2026, 8, 30);

Akte akte(String ordnername, {DateTime? geaendertAm}) => Akte(
  ordnername: ordnername,
  pfad: 'C:/Akten/$ordnername',
  geaendertAm: geaendertAm,
);

final bestand = [
  akte('VUnfallursache Mark', geaendertAm: DateTime(2026, 7, 1)),
  akte('Max Mustermann', geaendertAm: DateTime(2026, 6, 1)),
  akte('Bußgeldsache Saeed', geaendertAm: DateTime(2026, 7, 15)),
  akte('Strafsache Alt', geaendertAm: DateTime(2015, 1, 1)),
  akte('VUnfallursache Altfall', geaendertAm: DateTime(2016, 1, 1)),
];

List<String> namen(List<Akte> akten) => [for (final a in akten) a.ordnername];

void main() {
  test(
    'zeigt standardmäßig nur, was als Verkehrsunfallsache in Frage kommt',
    () {
      const filter = ZuordnungFilter();

      expect(namen(filter.anwenden(bestand, jetzt: jetzt)), [
        'VUnfallursache Mark',
        'Max Mustermann',
        'VUnfallursache Altfall',
      ]);
    },
  );

  // Beiseitegelegt heißt nicht gelöscht: die Zahlen daneben müssen stimmen,
  // sonst findet niemand die anderen Töpfe wieder.
  test('zählt jeden Topf getrennt mit', () {
    final zaehler = const ZuordnungFilter().zaehlen(bestand, jetzt: jetzt);

    expect(zaehler[OrdnerAnsicht.stapel], 3);
    expect(zaehler[OrdnerAnsicht.andere], 2);
    expect(zaehler[OrdnerAnsicht.ohneBezug], 0);
  });

  test('„Andere Ordner" zeigt die übrigen Sachgebiete', () {
    const filter = ZuordnungFilter(ansicht: OrdnerAnsicht.andere);

    expect(namen(filter.anwenden(bestand, jetzt: jetzt)), [
      'Bußgeldsache Saeed',
      'Strafsache Alt',
    ]);
  });

  // Die ausdrückliche Entscheidung des Anwalts sticht die Heuristik: ein
  // vermerkter Verkehrsunfall-Ordner steht nicht mehr im Arbeitsvorrat.
  test('ein Vermerk holt den Ordner aus seinem bisherigen Topf', () {
    final vermerkt = OrdnernamenMenge(const [
      'VUnfallursache Mark',
      'Bußgeldsache Saeed',
    ]);

    final zaehler = const ZuordnungFilter().zaehlen(
      bestand,
      ohneMandantenbezug: vermerkt,
      jetzt: jetzt,
    );
    expect(zaehler[OrdnerAnsicht.stapel], 2);
    expect(zaehler[OrdnerAnsicht.andere], 1);
    expect(zaehler[OrdnerAnsicht.ohneBezug], 2);

    const ansicht = ZuordnungFilter(ansicht: OrdnerAnsicht.ohneBezug);
    expect(
      namen(
        ansicht.anwenden(bestand, ohneMandantenbezug: vermerkt, jetzt: jetzt),
      ),
      ['VUnfallursache Mark', 'Bußgeldsache Saeed'],
    );
  });

  // Der Vermerk hängt am Ordnernamen, und der kommt aus dem Dateisystem:
  // „VUnfallursache Mark" und „vunfallursache mark" sind derselbe Ordner.
  test('ein Vermerk greift unabhängig von der Schreibweise', () {
    final vermerkt = OrdnernamenMenge(const ['vunfallursache mark']);

    final zaehler = const ZuordnungFilter().zaehlen(
      bestand,
      ohneMandantenbezug: vermerkt,
      jetzt: jetzt,
    );

    expect(zaehler[OrdnerAnsicht.ohneBezug], 1);
    expect(zaehler[OrdnerAnsicht.stapel], 2);
  });

  test('das Zeitfenster nimmt Altakten aus dem Stapel', () {
    const filter = ZuordnungFilter(geaendertSeit: GeaendertSeit.zwoelfMonate);

    expect(namen(filter.anwenden(bestand, jetzt: jetzt)), [
      'VUnfallursache Mark',
      'Max Mustermann',
    ]);
    // Auch die Zahlen der anderen Töpfe richten sich nach dem Zeitfenster,
    // sonst sprängen sie beim Umschalten.
    expect(filter.zaehlen(bestand, jetzt: jetzt)[OrdnerAnsicht.andere], 1);
  });

  test(
    'die Suche greift auf dem Ordnernamen, unabhängig von der Schreibweise',
    () {
      const filter = ZuordnungFilter(query: 'mUSTER');

      expect(namen(filter.anwenden(bestand, jetzt: jetzt)), ['Max Mustermann']);
    },
  );

  // „sache" steckt auch in „VUnfallursache" — genau deshalb muss der Topf
  // neben der Suche greifen und nicht statt ihrer.
  test('Suche und Topf greifen zusammen', () {
    const stapel = ZuordnungFilter(query: 'sache');
    expect(namen(stapel.anwenden(bestand, jetzt: jetzt)), [
      'VUnfallursache Mark',
      'VUnfallursache Altfall',
    ]);

    const andere = ZuordnungFilter(
      query: 'sache',
      ansicht: OrdnerAnsicht.andere,
    );
    expect(namen(andere.anwenden(bestand, jetzt: jetzt)), [
      'Bußgeldsache Saeed',
      'Strafsache Alt',
    ]);
  });

  // Ein nicht lesbares stat ist kein Grund, Arbeit aus dem Stapel zu nehmen.
  test('ohne Änderungszeitpunkt bleibt der Ordner sichtbar', () {
    const filter = ZuordnungFilter(geaendertSeit: GeaendertSeit.zwoelfMonate);

    expect(filter.anwenden([akte('Ohne Datum')], jetzt: jetzt), hasLength(1));
  });
}
