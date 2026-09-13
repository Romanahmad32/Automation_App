import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Zuordnen und Lösen von der Mandantenkarte aus (#132) — am Bloc geprüft.
/// Wie beim Zuordnungsstapel gilt: Der Zustand wird fortgeschrieben, der
/// Stammordner **nicht** neu gescannt.
void main() {
  late MandantenTestaufbau aufbau;

  MandantenTestaufbau mit({
    List<String> ordnerAmMandanten = const [],
    List<String> akten = const ['VUnfallursache Mark', 'Bußgeldsache Saeed'],
  }) => MandantenTestaufbau(
    register: [mandant(1, 'Mustermann', ordner: ordnerAmMandanten)],
    akten: [for (final name in akten) akte(name)],
  );

  tearDown(() => aufbau.close());

  List<String> stapel(MandantenOverviewLoaded s) => [
    for (final a in s.nichtZugeordneteAkten) a.ordnername,
  ];

  test('Lösen bringt den Ordner zurück in den Stapel, ohne Rescan', () async {
    aufbau = mit(ordnerAmMandanten: ['VUnfallursache Mark']);
    final geladen = await aufbau.laden();
    expect(stapel(geladen), ['Bußgeldsache Saeed']);

    aufbau.bloc.add(
      const LoeseOrdnerEvent(mandantId: 1, ordnername: 'VUnfallursache Mark'),
    );
    final nachher = await aufbau.naechster();

    expect(aufbau.getAkten.aufrufe, 1);
    expect(nachher.mandanten.single.aktenOrdnernamen, isEmpty);
    expect(nachher.aktenFuer(nachher.mandanten.single), isEmpty);
    expect(stapel(nachher), ['VUnfallursache Mark', 'Bußgeldsache Saeed']);
  });

  // Der Name am Mandanten kann anders geschrieben sein als der auf der Platte
  // — der Import übernimmt ihn aus einer Maschinendatei. Genau verglichen
  // bliebe der Ordner zugeordnet und stünde trotzdem nicht im Stapel.
  test('Lösen greift unabhängig von der Schreibweise', () async {
    aufbau = mit(ordnerAmMandanten: ['vunfallursache MARK']);
    await aufbau.laden();

    aufbau.bloc.add(
      const LoeseOrdnerEvent(mandantId: 1, ordnername: 'VUnfallursache Mark'),
    );
    final nachher = await aufbau.naechster();

    expect(nachher.mandanten.single.aktenOrdnernamen, isEmpty);
    expect(stapel(nachher), contains('VUnfallursache Mark'));
  });

  test('Zuordnen nimmt den Vermerk „ohne Mandantenbezug" zurück', () async {
    aufbau = mit();
    aufbau.ordnerStatus.eintraege['Bußgeldsache Saeed'] = OrdnerStatus(
      ordnername: 'Bußgeldsache Saeed',
      art: OrdnerStatusArt.ohneMandantenbezug,
      gesetztAm: angelegt,
    );
    final geladen = await aufbau.laden();
    expect(geladen.ohneMandantenbezug.enthaelt('Bußgeldsache Saeed'), isTrue);

    // Vor dem Ereignis abonnieren: Die Zuordnung und die Rücknahme des
    // Vermerks sind zwei Zustände kurz hintereinander, und zwischen zwei
    // `stream.first` ginge der zweite verloren.
    final ohneVermerk = aufbau.bloc.stream.firstWhere(
      (s) => s is MandantenOverviewLoaded && s.ohneMandantenbezug.isEmpty,
    );
    aufbau.bloc.add(
      const VerknuepfeOrdnerEvent(
        mandantId: 1,
        ordnername: 'Bußgeldsache Saeed',
      ),
    );
    final zugeordnet = await ohneVermerk as MandantenOverviewLoaded;

    expect(zugeordnet.mandanten.single.aktenOrdnernamen, [
      'Bußgeldsache Saeed',
    ]);
    expect(aufbau.ordnerStatus.setzAufrufe, 1);

    // Und nach dem Lösen landet er im Arbeitsvorrat, nicht unter
    // „Beiseitegelegt".
    aufbau.bloc.add(
      const LoeseOrdnerEvent(mandantId: 1, ordnername: 'Bußgeldsache Saeed'),
    );
    final geloest = await aufbau.naechster();
    expect([
      for (final a in geloest.offeneOrdnerFuerPaket) a.ordnername,
    ], contains('Bußgeldsache Saeed'));
  });

  test('ein Ordner ohne Vermerk kostet beim Zuordnen keinen zweiten '
      'Aufruf', () async {
    aufbau = mit();
    await aufbau.laden();

    aufbau.bloc.add(
      const VerknuepfeOrdnerEvent(
        mandantId: 1,
        ordnername: 'VUnfallursache Mark',
      ),
    );
    await aufbau.naechster();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(aufbau.ordnerStatus.setzAufrufe, 0);
  });

  group('nichtGefundeneOrdnerFuer', () {
    test('nennt zugeordnete Ordner, die der Scan nicht findet', () async {
      aufbau = mit(ordnerAmMandanten: ['VUnfallursache Mark', 'Umbenannt']);
      final geladen = await aufbau.laden();
      final m = geladen.mandanten.single;

      expect(geladen.nichtGefundeneOrdnerFuer(m), ['Umbenannt']);
      expect(
        [for (final a in geladen.aktenFuer(m)) a.ordnername],
        ['VUnfallursache Mark'],
      );
    });

    test('in anderer Schreibweise gilt der Ordner als gefunden', () async {
      aufbau = mit(ordnerAmMandanten: ['VUNFALLURSACHE mark']);
      final geladen = await aufbau.laden();

      expect(geladen.nichtGefundeneOrdnerFuer(geladen.mandanten.single), []);
    });

    // Stammordner nicht gesetzt oder das Netzlaufwerk weg: Der Scan ist leer.
    // Dann fehlte scheinbar jede Akte — und die Karte riete zum Lösen.
    test('ohne Scan-Ergebnis meldet er nichts als fehlend', () async {
      aufbau = mit(ordnerAmMandanten: ['VUnfallursache Mark'], akten: []);
      final geladen = await aufbau.laden();

      expect(geladen.nichtGefundeneOrdnerFuer(geladen.mandanten.single), []);
    });
  });
}
