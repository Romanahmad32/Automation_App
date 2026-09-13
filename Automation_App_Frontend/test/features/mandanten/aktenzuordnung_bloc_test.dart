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

  // Den Vermerk nimmt der Dienst mit der Zuordnung zurück (und ebenso bei
  // Ablage und neuem Mandanten). Der Bloc streicht ihn nur aus dem Zustand —
  // ohne eigenen Aufruf, in demselben Zustandswechsel wie die Zuordnung.
  test('Zuordnen streicht den Vermerk „ohne Mandantenbezug" aus dem '
      'Zustand', () async {
    aufbau = mit();
    aufbau.ordnerStatus.eintraege['Bußgeldsache Saeed'] = OrdnerStatus(
      ordnername: 'Bußgeldsache Saeed',
      art: OrdnerStatusArt.ohneMandantenbezug,
      gesetztAm: angelegt,
    );
    final geladen = await aufbau.laden();
    expect(geladen.ohneMandantenbezug.enthaelt('Bußgeldsache Saeed'), isTrue);

    aufbau.bloc.add(
      const VerknuepfeOrdnerEvent(
        mandantId: 1,
        ordnername: 'bußgeldsache SAEED',
      ),
    );
    final zugeordnet = await aufbau.naechster();

    expect(zugeordnet.mandanten.single.aktenOrdnernamen, [
      'bußgeldsache SAEED',
    ]);
    expect(zugeordnet.ohneMandantenbezug.isEmpty, isTrue);
    expect(aufbau.ordnerStatus.setzAufrufe, 0);

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

  group('faelleNachladen', () {
    VerknuepfeOrdnerEvent zuordnen({required bool faelleNachladen}) =>
        VerknuepfeOrdnerEvent(
          mandantId: 1,
          ordnername: 'VUnfallursache Mark',
          faelleNachladen: faelleNachladen,
        );

    test('von der Karte liest die Fälle der neuen Akte nach', () async {
      aufbau = mit();
      await aufbau.laden();

      // Vor dem Ereignis abonnieren: Zuordnung und Fälle sind zwei Zustände
      // kurz hintereinander, und zwischen zwei `stream.first` ginge der
      // zweite verloren.
      final mitFaellen = aufbau.bloc.stream.firstWhere(
        (s) =>
            s is MandantenOverviewLoaded &&
            s.akten.any(
              (a) => a.ordnername == 'VUnfallursache Mark' && a.faelleGeladen,
            ),
      );
      aufbau.bloc.add(zuordnen(faelleNachladen: true));
      await mitFaellen;

      expect(aufbau.getFaelle.aufrufe, 1);
    });

    test('aus dem Stapel liest keine Fälle', () async {
      aufbau = mit();
      await aufbau.laden();

      aufbau.bloc.add(zuordnen(faelleNachladen: false));
      await aufbau.naechster();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(aufbau.getFaelle.aufrufe, 0);
    });

    // Bei einem 409 gehört die Akte einem anderen — ihre Fälle vom
    // Netzlaufwerk zu lesen wäre Arbeit für eine Karte, an der sie nie steht.
    test('eine gescheiterte Zuordnung liest keine Fälle', () async {
      aufbau = mit();
      await aufbau.laden();
      aufbau.register.fehlerBeimVerknuepfen = 'gehört bereits Schulz';

      aufbau.bloc.add(zuordnen(faelleNachladen: true));
      final nachher = await aufbau.naechster();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(nachher.fehler, 'gehört bereits Schulz');
      expect(aufbau.getFaelle.aufrufe, 0);
    });
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
