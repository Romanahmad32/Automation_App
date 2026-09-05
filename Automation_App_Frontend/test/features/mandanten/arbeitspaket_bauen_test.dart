import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/services/arbeitspaket_bauen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arbeitspaket_testaufbau.dart';

/// Der Bauer entscheidet nur zwei Dinge — welche Ordner ins Paket kommen und in
/// welcher Reihenfolge. Seit dem Schnitt nach **Mandanten** haengt daran mehr
/// als Bequemlichkeit: eine Person, die ueber zwei Pakete zerrissen wird, legt
/// der Agent zweimal an. Genau die Dublette soll der Import verhindern.
///
/// Und beides muss sich wiederholen lassen: der Anwalt holt ein Paket, bricht
/// ab, holt es erneut und will dieselben Ordner sehen.
void main() {
  group('ArbeitspaketBauen.baue — Schnitt nach Mandanten', () {
    test('alle Ordner einer Person liegen zusammenhaengend im Paket', () {
      final paket = bauePaket([
        ...ordnerVonPerson('Bernd', 'Adler'),
        ...ordnerVonPerson('Anna', 'Meier', anzahl: 2),
      ]);

      expect(paket.ordnernamen, [
        'Strafsache Anna Meier',
        'VUnfallursache Anna Meier',
        'VUnfallursache Bernd Adler',
      ]);
    });

    test(
      'anzahl zaehlt Personen: drei Personen koennen sieben Ordner sein',
      () {
        final paket = bauePaket([
          ...ordnerVonPerson('Anna', 'Meier', anzahl: 3),
          ...ordnerVonPerson('Bernd', 'Adler', anzahl: 2),
          ...ordnerVonPerson('Clara', 'Zeller', anzahl: 2),
          ...ordnerVonPerson('Doris', 'Ehlers'),
        ], anzahl: 3);

        expect(ArbeitspaketBauen.mandantenAnzahl(paket.ordner), 3);
        expect(paket.ordner, hasLength(7));
        expect(
          paket.ordnernamen,
          isNot(contains('VUnfallursache Doris Ehlers')),
        );
      },
    );

    // So laeuft die Arbeit wirklich: Paket 1 wird abgearbeitet, seine Ordner
    // sind danach zugeordnet oder vermerkt und fallen aus der offenen Menge.
    // Keine Person darf dabei in beiden Paketen stehen — sonst sieht der Agent
    // beim zweiten Mal einen Mandanten, den er beim ersten schon angelegt hat.
    test('ein Mandant wird nie ueber zwei Pakete verteilt', () {
      final offen = [
        ...ordnerVonPerson('Anna', 'Meier', anzahl: 3),
        ...ordnerVonPerson('Bernd', 'Adler', anzahl: 2),
        ...ordnerVonPerson('Clara', 'Zeller', anzahl: 2),
      ];

      final erstes = bauePaket(offen, anzahl: 2);
      final erledigt = OrdnernamenMenge(erstes.ordnernamen);
      final rest = [
        for (final ordner in offen)
          if (!erledigt.enthaelt(ordner.ordnername)) ordner,
      ];
      final zweites = bauePaket(rest, nummer: 2, anzahl: 2);

      expect(erstes.ordner, hasLength(5));
      expect(zweites.ordner, hasLength(2));
      expect(personenIm(zweites).intersection(personenIm(erstes)), isEmpty);
    });

    // Eine Verkehrsunfall-App braucht aus Straf-, Bussgeld- und Familiensachen
    // keine Stammdaten. Wer nur die vorderen Pakete abarbeitet, soll trotzdem
    // das Wesentliche erfasst haben.
    test('Gruppen mit Unfallkandidat kommen vor Gruppen ohne', () {
      final paket = bauePaket([
        paketOrdner(
          'Strafsache Anton Abel',
          aktentyp: Aktentyp.straf,
          vorname: 'Anton',
          nachname: 'Abel',
        ),
        paketOrdner(
          'Bussgeldsache Berta Baum',
          aktentyp: Aktentyp.bussgeld,
          vorname: 'Berta',
          nachname: 'Baum',
        ),
        ...ordnerVonPerson('Zora', 'Zeller'),
      ]);

      // Hinter dem Vorrang wird nach dem Gruppenschluessel sortiert, und der
      // ist der Name der Person — nicht der Ordnername mit seinem Praefix.
      expect(paket.ordnernamen, [
        'VUnfallursache Zora Zeller',
        'Strafsache Anton Abel',
        'Bussgeldsache Berta Baum',
      ]);
    });

    // Die Heuristik darf Arbeit ersparen, aber nichts verschlucken: ein Ordner
    // ohne erkennbaren Namen ist eine eigene Gruppe, keine Sammelgruppe.
    test('ein Ordner ohne erkennbaren Namen geht nicht verloren', () {
      final paket = bauePaket([
        paketOrdner('Buchhaltung 2024', aktentyp: Aktentyp.ohnePraefix),
        ...ordnerVonPerson('Anna', 'Meier', anzahl: 2),
      ]);

      expect(paket.ordnernamen, [
        'Strafsache Anna Meier',
        'VUnfallursache Anna Meier',
        'Buchhaltung 2024',
      ]);
      expect(ArbeitspaketBauen.mandantenAnzahl(paket.ordner), 2);
    });
  });

  group('ArbeitspaketBauen.baue — Reihenfolge und Portion', () {
    test(
      'sortiert alphabetisch ohne Ruecksicht auf Gross-/Kleinschreibung',
      () {
        final paket = bauePaket([
          paketOrdner('vunfallursache Zimmer'),
          paketOrdner('VUnfallursache Anders'),
          paketOrdner('VUnfallursache mueller'),
        ]);

        expect(paket.ordnernamen, [
          'VUnfallursache Anders',
          'VUnfallursache mueller',
          'vunfallursache Zimmer',
        ]);
      },
    );

    // Ohne Namensvorschlag ist jeder Ordner seine eigene Gruppe — die Portion
    // zaehlt dann Ordner, weil jeder Ordner eine Person ist.
    test('nimmt die ersten anzahl Gruppen', () {
      final paket = bauePaket(vieleOrdner(500), anzahl: 200);

      expect(paket.ordner, hasLength(200));
      expect(paket.ordnernamen.first, 'VUnfallursache 0000');
      expect(paket.ordnernamen.last, 'VUnfallursache 0199');
    });

    test('deckelt die Anzahl auf 1000', () {
      final paket = bauePaket(vieleOrdner(1500), anzahl: 5000);

      expect(paket.ordner, hasLength(ArbeitspaketBauen.hoechsteAnzahl));
    });

    test('hebt eine Anzahl unter 1 auf 1 an', () {
      expect(bauePaket(vieleOrdner(10), anzahl: 0).ordner, hasLength(1));
      expect(bauePaket(vieleOrdner(10), anzahl: -7).ordner, hasLength(1));
    });

    test('weniger offene Mandanten als angefordert ist kein Fehler', () {
      final paket = bauePaket(vieleOrdner(12), anzahl: 200);

      expect(paket.ordner, hasLength(12));
    });

    test('gar keine offenen Ordner ergibt ein leeres Paket', () {
      final paket = bauePaket(const []);

      expect(paket.ordner, isEmpty);
      expect(paket.ordnernamen, isEmpty);
    });

    test('uebernimmt Rahmendaten und Nummer unveraendert', () {
      final paket = bauePaket(vieleOrdner(3), nummer: 7);

      expect(paket.paket, 7);
      expect(paket.version, Arbeitspaket.aktuelleVersion);
      expect(paket.erstelltAm, erstellt);
      expect(paket.stammordner, 'D:/Akten');
      expect(paket.dateiname, 'arbeitspaket-7.json');
    });

    // Der Kern der Sache: der Bauer bekommt bei jedem Anlauf dieselbe Menge in
    // moeglicherweise anderer Reihenfolge (ein Verzeichnis-Scan garantiert
    // keine), und `List.sort` ist in Dart nicht stabil.
    test('zweimal bauen ohne Aenderung ergibt dieselben Ordner', () {
      final offen = vieleOrdner(400);
      final erstes = bauePaket(offen, anzahl: 200);
      final zweites = bauePaket(offen.reversed.toList(), anzahl: 200);

      expect(zweites.ordnernamen, erstes.ordnernamen);
    });

    test('gleiche Namen in verschiedener Schreibweise ordnen sich stabil', () {
      final offen = [
        paketOrdner('Vunfallursache Mark'),
        paketOrdner('VUnfallursache Mark'),
      ];

      final erstes = bauePaket(offen);
      final zweites = bauePaket(offen.reversed.toList());

      expect(erstes.ordnernamen, zweites.ordnernamen);
    });

    test(
      'das naechste Paket liefert die naechsten 200 ohne Ueberschneidung',
      () {
        final offen = vieleOrdner(500);
        final erstes = bauePaket(offen, anzahl: 200);

        final erledigt = OrdnernamenMenge(erstes.ordnernamen);
        final rest = [
          for (final ordner in offen)
            if (!erledigt.enthaelt(ordner.ordnername)) ordner,
        ];
        final zweites = bauePaket(rest, nummer: 2, anzahl: 200);

        expect(zweites.ordner, hasLength(200));
        expect(
          zweites.ordnernamen.toSet().intersection(erstes.ordnernamen.toSet()),
          isEmpty,
        );
        expect(zweites.ordnernamen.first, 'VUnfallursache 0200');
        expect(zweites.ordnernamen.last, 'VUnfallursache 0399');
      },
    );
  });

  group('ArbeitspaketBauen.gruppenschluessel', () {
    // Dieselbe Normalisierung wie bei der Wiedererkennung: waere sie hier eine
    // andere, zerfiele „Mueller" in zwei Personen, die jede Erkennung daneben
    // fuer eine haelt.
    test('fasst Schreibweise und Umlaute zusammen', () {
      final einer = paketOrdner(
        'VUnfallursache Anna Müller',
        vorname: 'Anna',
        nachname: 'Müller',
      );
      final anderer = paketOrdner(
        'Strafsache ANNA MUELLER',
        aktentyp: Aktentyp.straf,
        vorname: 'ANNA',
        nachname: 'MUELLER',
      );

      expect(
        ArbeitspaketBauen.gruppenschluessel(einer),
        ArbeitspaketBauen.gruppenschluessel(anderer),
      );
      expect(ArbeitspaketBauen.mandantenAnzahl([einer, anderer]), 1);
    });

    test('faellt ohne Namensvorschlag auf den Ordnernamen zurueck', () {
      expect(
        ArbeitspaketBauen.gruppenschluessel(paketOrdner('Buchhaltung 2024')),
        'buchhaltung 2024',
      );
    });

    // Ein leerer Schluessel waere der Sammeltopf, in dem alles Unerkannte als
    // eine Person staende.
    test('zwei namenlose Ordner sind zwei Gruppen', () {
      expect(
        ArbeitspaketBauen.mandantenAnzahl([
          paketOrdner('Buchhaltung'),
          paketOrdner('Vorlagen'),
        ]),
        2,
      );
    });

    test('mandantenAnzahl zaehlt Personen, nicht Ordner', () {
      expect(
        ArbeitspaketBauen.mandantenAnzahl(
          ordnerVonPerson('Anna', 'Meier', anzahl: 3),
        ),
        1,
      );
    });
  });
}
