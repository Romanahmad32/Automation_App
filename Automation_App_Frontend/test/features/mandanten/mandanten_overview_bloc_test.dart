import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

void main() {
  late MandantenTestaufbau aufbau;

  MandantenTestaufbau mit({List<String> ordnerAmMandanten = const []}) =>
      MandantenTestaufbau(
        register: [mandant(1, 'Mustermann', ordner: ordnerAmMandanten)],
        akten: [akte('VUnfallursache Mark'), akte('Bußgeldsache Saeed')],
        faelle: [
          Fall(
            name: 'Unfall v. 12.05.2019',
            pfad: 'C:/Akten/VUnfallursache Mark/Unfall v. 12.05.2019',
            geaendertAm: angelegt,
          ),
        ],
      );

  setUp(() => aufbau = mit());
  tearDown(() => aufbau.close());

  test('der Erst-Scan liefert die Ordner ohne ihre Fälle', () async {
    final geladen = await aufbau.laden();

    expect(geladen.akten, hasLength(2));
    expect(geladen.akten.every((a) => !a.faelleGeladen), isTrue);
    expect(aufbau.getFaelle.aufrufe, 0);
  });

  test('Fälle kommen erst auf Anforderung und dann nur einmal', () async {
    final geladen = await aufbau.laden();

    aufbau.bloc.add(LadeFaelleEvent(geladen.akten.first));
    final mitFaellen = await aufbau.naechster();
    expect(mitFaellen.akten.first.faelleGeladen, isTrue);
    expect(mitFaellen.akten.first.faelle, hasLength(1));
    expect(aufbau.getFaelle.aufrufe, 1);

    // Zweites Aufklappen derselben Akte: nichts nachzuladen.
    aufbau.bloc.add(LadeFaelleEvent(mitFaellen.akten.first));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(aufbau.getFaelle.aufrufe, 1);
  });

  // Der eigentliche Fehler aus dem Bericht: bei rund 4000 Ordnern kostete jede
  // einzelne Zuordnung einen vollständigen Rescan des Stammordners.
  test(
    'eine Zuordnung schreibt den Zustand fort statt neu zu scannen',
    () async {
      final geladen = await aufbau.laden();
      expect(geladen.nichtZugeordneteAkten, hasLength(2));
      expect(aufbau.getAkten.aufrufe, 1);

      aufbau.bloc.add(
        const VerknuepfeOrdnerEvent(
          mandantId: 1,
          ordnername: 'VUnfallursache Mark',
        ),
      );
      final nachher = await aufbau.naechster();

      expect(aufbau.getAkten.aufrufe, 1);
      expect(nachher.mandanten.single.aktenOrdnernamen, [
        'VUnfallursache Mark',
      ]);
      expect(
        [for (final a in nachher.nichtZugeordneteAkten) a.ordnername],
        ['Bußgeldsache Saeed'],
      );
    },
  );

  test('ein gelöschter Mandant gibt seine Ordner ohne Rescan frei', () async {
    await aufbau.close();
    aufbau = mit(ordnerAmMandanten: ['VUnfallursache Mark']);

    final geladen = await aufbau.laden();
    expect(geladen.nichtZugeordneteAkten, hasLength(1));

    aufbau.bloc.add(const DeleteMandantEvent(1));
    final nachher = await aufbau.naechster();

    expect(aufbau.getAkten.aufrufe, 1);
    expect(nachher.mandanten, isEmpty);
    expect(nachher.nichtZugeordneteAkten, hasLength(2));
  });

  test('nurRegister holt das Register, lässt den Scan aber stehen', () async {
    await aufbau.laden();

    aufbau.bloc.add(const LoadMandantenUebersichtEvent(nurRegister: true));
    await aufbau.bloc.stream.firstWhere(
      (s) => s is MandantenOverviewLoaded && !s.neuLadend,
    );

    expect(aufbau.getMandanten.aufrufe, 2);
    expect(aufbau.getAkten.aufrufe, 1);
  });

  // Stufe 2 aus Issue #19: die Entscheidung ist ein Status, kein Ausblenden —
  // der Ordner verlässt den Arbeitsvorrat und ist trotzdem noch da.
  test(
    'ein Vermerk nimmt den Ordner aus dem Stapel, ohne neu zu scannen',
    () async {
      final geladen = await aufbau.laden();
      expect(geladen.offeneOrdnerAnzahl, 2);

      aufbau.bloc.add(
        const SetzeOrdnerStatusEvent(
          ordnernamen: ['Bußgeldsache Saeed'],
          art: OrdnerStatusArt.ohneMandantenbezug,
        ),
      );
      final nachher = await aufbau.naechster();

      expect(aufbau.getAkten.aufrufe, 1);
      expect(nachher.offeneOrdnerAnzahl, 1);
      expect(nachher.ohneMandantenbezug, {'Bußgeldsache Saeed'});
      expect(nachher.ordnerZaehler[OrdnerAnsicht.ohneBezug], 1);
      // Nicht verschwunden, nur einsortiert.
      expect(nachher.nichtZugeordneteAkten, hasLength(2));
    },
  );

  test('der Vermerk lässt sich zurücknehmen', () async {
    await aufbau.laden();

    aufbau.bloc.add(
      const SetzeOrdnerStatusEvent(
        ordnernamen: ['Bußgeldsache Saeed'],
        art: OrdnerStatusArt.ohneMandantenbezug,
      ),
    );
    await aufbau.naechster();

    aufbau.bloc.add(
      const SetzeOrdnerStatusEvent(
        ordnernamen: ['Bußgeldsache Saeed'],
        art: null,
      ),
    );
    final zurueck = await aufbau.naechster();

    expect(zurueck.ohneMandantenbezug, isEmpty);
    expect(zurueck.offeneOrdnerAnzahl, 2);
  });

  // Stufe 3: einzeln wäre der Rest von rund 4000 Ordnern nicht zu schaffen —
  // die Massenaktion muss ein Aufruf bleiben, nicht einer je Ordner.
  test('die Massenaktion setzt alle Ordner in einem Aufruf', () async {
    await aufbau.laden();

    aufbau.bloc.add(
      const SetzeOrdnerStatusEvent(
        ordnernamen: ['VUnfallursache Mark', 'Bußgeldsache Saeed'],
        art: OrdnerStatusArt.ohneMandantenbezug,
      ),
    );
    final nachher = await aufbau.naechster();

    expect(aufbau.ordnerStatus.setzAufrufe, 1);
    expect(nachher.offeneOrdnerAnzahl, 0);
  });

  test('der Zuordnungsfilter überlebt ein Neuladen', () async {
    await aufbau.laden();

    aufbau.bloc.add(
      const SetzeZuordnungFilterEvent(ZuordnungFilter(query: 'Mark')),
    );
    final gefiltert = await aufbau.naechster();
    expect(gefiltert.sichtbareNichtZugeordnete, hasLength(1));

    aufbau.bloc.add(const LoadMandantenUebersichtEvent());
    final neu = await aufbau.bloc.stream.firstWhere(
      (s) => s is MandantenOverviewLoaded && !s.neuLadend,
    );
    expect((neu as MandantenOverviewLoaded).zuordnungFilter.query, 'Mark');
  });
}
