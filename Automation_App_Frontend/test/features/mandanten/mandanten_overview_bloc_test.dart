import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

void main() {
  // `schreibeUndVerbucheArbeitspaket` legt die Anleitung per
  // `Clipboard.setData` ab — das braucht eine initialisierte Flutter-Bindung
  // auch in reinen `test()`-Fällen ohne `testWidgets`, UND eine Attrappe für
  // den Kanal: ohne sie geht der Aufruf auf den echten
  // `SystemChannels.platform`-Kanal, der im `flutter_tester` (kein eigenes
  // Fenster, kein Zwischenablage-Eigentümer) auf manchen Läufen nie
  // antwortet — das hat einen Testlauf zehn Minuten lang hängen lassen
  // (Befund des Masters).
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      });

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

  // Issue #108: die Paket-Historie für die Stand-Karte kommt beim Laden mit.
  group('Arbeitspaket (Issue #108)', () {
    test('die Paket-Historie kommt beim Laden mit', () async {
      await aufbau.close();
      aufbau = MandantenTestaufbau(
        importPakete: [
          ImportPaket(nummer: 1, geholtAm: angelegt, anzahlOrdner: 5),
        ],
      );

      final geladen = await aufbau.laden();

      expect(geladen.importPakete, hasLength(1));
      expect(geladen.importPakete.single.nummer, 1);
    });

    test(
      'baueArbeitspaket baut aus den offenen Ordnern mit der nächsten Nummer',
      () async {
        await aufbau.close();
        aufbau = MandantenTestaufbau(
          akten: [akte('VUnfallursache Mark'), akte('VUnfallursache Anna')],
          importPakete: [
            ImportPaket(nummer: 2, geholtAm: angelegt, anzahlOrdner: 10),
          ],
        );
        await aufbau.laden();

        final paket = await aufbau.bloc.baueArbeitspaket(200);

        expect(paket.paket, 3);
        expect(paket.stammordner, 'C:/Akten');
        expect(paket.ordnernamen, [
          'VUnfallursache Anna',
          'VUnfallursache Mark',
        ]);
      },
    );

    // Befund aus dem Code Review zu Issue #108: `baue` sucht seit der
    // Umstellung auf `MandantenNamensindex` nicht mehr gegen den vollen
    // Bestand, sondern über den Vorfilter. Der Index darf nichts ausschließen,
    // was `MandantErkennung.finde` gefunden hätte — dieser Test belegt das an
    // einem Ordner, der vorher einen `bekannterMandant` bekam.
    test(
      'baueArbeitspaket findet weiterhin den bekannten Mandanten je Ordner',
      () async {
        await aufbau.close();
        aufbau = MandantenTestaufbau(
          register: [mandant(1, 'Mustermann', vorname: 'Max')],
          akten: [
            akte('VUnfallursache Max Mustermann'),
            akte('VUnfallursache Anna Unbekannt'),
          ],
        );
        await aufbau.laden();

        final paket = await aufbau.bloc.baueArbeitspaket(200);

        final treffer = paket.ordner.firstWhere(
          (o) => o.ordnername == 'VUnfallursache Max Mustermann',
        );
        expect(treffer.bekannterMandant, 'Max Mustermann');
        expect(treffer.begruendung, isNotNull);

        final ohneTreffer = paket.ordner.firstWhere(
          (o) => o.ordnername == 'VUnfallursache Anna Unbekannt',
        );
        expect(ohneTreffer.bekannterMandant, isNull);
      },
    );

    test('schreibeUndVerbucheArbeitspaket schreibt, verbucht und aktualisiert '
        'die Historie', () async {
      await aufbau.close();
      aufbau = MandantenTestaufbau(akten: [akte('VUnfallursache Mark')]);
      await aufbau.laden();

      final paket = await aufbau.bloc.baueArbeitspaket(200);
      final ergebnis = await aufbau.bloc.schreibeUndVerbucheArbeitspaket(
        paket: paket,
        pfad: 'C:/Ablage/arbeitspaket-1.json',
      );

      expect(ergebnis, isA<Right>());
      expect(aufbau.arbeitspaketDatei.schreibAufrufe, 1);
      expect(
        aufbau.arbeitspaketDatei.letzterPfad,
        'C:/Ablage/arbeitspaket-1.json',
      );
      expect(aufbau.paketeSpeicher.notiereAufrufe, 1);

      final aktuell = aufbau.bloc.state as MandantenOverviewLoaded;
      expect(aktuell.importPakete, hasLength(1));
      expect(aktuell.importPakete.single.nummer, 1);
    });

    test('schreibeUndVerbucheArbeitspaket verbucht nicht, wenn das Schreiben '
        'scheitert', () async {
      await aufbau.close();
      aufbau = MandantenTestaufbau(akten: [akte('VUnfallursache Mark')]);
      await aufbau.laden();
      aufbau.arbeitspaketDatei.fehlerBeimSchreiben = 'Datenträger voll';

      final paket = await aufbau.bloc.baueArbeitspaket(200);
      final ergebnis = await aufbau.bloc.schreibeUndVerbucheArbeitspaket(
        paket: paket,
        pfad: 'C:/Ablage/arbeitspaket-1.json',
      );

      expect(ergebnis, isA<Left>());
      expect(aufbau.paketeSpeicher.notiereAufrufe, 0);
    });
  });
}
