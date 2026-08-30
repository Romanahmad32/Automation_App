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

    expect(aufbau.register.seitenAufrufe, 2);
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
      expect(nachher.ohneMandantenbezug.enthaelt('Bußgeldsache Saeed'), isTrue);
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

    expect(zurueck.ohneMandantenbezug.isEmpty, isTrue);
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

  // Paket B: in der Kanzlei stehen tausende Mandanten im Register. Die Liste
  // holt sie seitenweise — und die Suche trotzdem über den ganzen Bestand.
  test('die Mandantenliste kommt seitenweise und lädt nach', () async {
    await aufbau.close();
    aufbau = MandantenTestaufbau(
      register: [for (var i = 0; i < 120; i++) mandant(i + 1, 'Nachname $i')],
    );

    final geladen = await aufbau.laden();
    expect(geladen.mandanten, hasLength(MandantenOverviewBloc.seitenGroesse));
    expect(geladen.gesamtMandanten, 120);
    expect(geladen.gibtWeitereMandanten, isTrue);

    aufbau.bloc.add(const LadeWeitereMandantenEvent());
    await aufbau.naechster(); // mehrLadend
    final mehr = await aufbau.naechster();

    expect(mehr.mandanten, hasLength(100));
    expect(mehr.mandanten.map((m) => m.id).toSet(), hasLength(100));
  });

  test('die Suche fragt den Dienst und beginnt wieder oben', () async {
    await aufbau.close();
    aufbau = MandantenTestaufbau(
      register: [
        for (var i = 0; i < 60; i++) mandant(i + 1, 'Nachname $i'),
        mandant(99, 'Zuletzt'),
      ],
    );
    await aufbau.laden();

    aufbau.bloc.add(const SearchMandantenEvent('Zuletzt'));
    final gefunden = await aufbau.bloc.stream.firstWhere(
      (s) => s is MandantenOverviewLoaded && !s.neuLadend,
    );

    // Der gesuchte Mandant steht hinter der ersten Seite — im Speicher
    // gefiltert wäre er nicht dabei.
    final treffer = (gefunden as MandantenOverviewLoaded).mandanten;
    expect(treffer.single.nachname, 'Zuletzt');
    expect(gefunden.gefundeneMandanten, 1);
    expect(gefunden.gesamtMandanten, 61);
  });

  // Der Zuordnungsstapel hängt nicht mehr an der geladenen Seite: die
  // zugeordneten Ordner kommen für den ganzen Bestand.
  test('ein Ordner eines ungeladenen Mandanten bleibt zugeordnet', () async {
    await aufbau.close();
    aufbau = MandantenTestaufbau(
      register: [
        for (var i = 0; i < 60; i++) mandant(i + 1, 'Nachname $i'),
        mandant(99, 'Spaet', ordner: ['VUnfallursache Mark']),
      ],
      akten: [akte('VUnfallursache Mark'), akte('Bußgeldsache Saeed')],
    );

    final geladen = await aufbau.laden();

    expect(geladen.mandanten.any((m) => m.id == 99), isFalse);
    expect(
      [for (final a in geladen.nichtZugeordneteAkten) a.ordnername],
      ['Bußgeldsache Saeed'],
    );
  });

  // Ordnernamen kommen aus dem Dateisystem: „VUnfallursache Mark" und
  // „vunfallursache mark" sind derselbe Ordner.
  test('die Zuordnung greift unabhängig von der Schreibweise', () async {
    await aufbau.close();
    aufbau = MandantenTestaufbau(
      register: [
        mandant(1, 'Mustermann', ordner: ['vunfallursache mark']),
      ],
      akten: [akte('VUnfallursache Mark')],
    );

    final geladen = await aufbau.laden();

    expect(geladen.nichtZugeordneteAkten, isEmpty);
    expect(geladen.aktenFuer(geladen.mandanten.single), hasLength(1));
  });

  // Der Befund aus dem Code Review: eine gescheiterte Massenaktion darf nicht
  // den Scan über tausende Ordner samt Filter und Scrollstand mitnehmen.
  test('eine gescheiterte Massenaktion behält den geladenen Stand', () async {
    final geladen = await aufbau.laden();
    aufbau.ordnerStatus.fehlerBeimSetzen = 'Dienst nicht erreichbar';

    aufbau.bloc.add(
      const SetzeOrdnerStatusEvent(
        ordnernamen: ['VUnfallursache Mark', 'Bußgeldsache Saeed'],
        art: OrdnerStatusArt.ohneMandantenbezug,
      ),
    );
    final nachher = await aufbau.naechster();

    expect(nachher.fehler, 'Dienst nicht erreichbar');
    expect(nachher.akten, geladen.akten);
    expect(nachher.offeneOrdnerAnzahl, 2);

    aufbau.bloc.add(const FehlerVerwerfenEvent());
    expect((await aufbau.naechster()).fehler, isNull);
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
