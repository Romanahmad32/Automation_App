import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/sichere_treffer.dart';
import 'package:automation_app/features/mandanten/presentation/utils/ordnername_vorschlag.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// „Sicher" ist eng gemeint, und der Test steht genau dafuer ein: jeder Fall
/// hier, der nicht durchkommt, waere sonst eine Akte am falschen Mandanten —
/// und die findet niemand mehr, weil sie zugeordnet *aussieht*.
///
/// Der Namensvorschlag kommt von aussen herein (`nameVorschlagAusOrdner` aus
/// der Praesentation), damit die eine Praefixtabelle die eine bleibt. Der Test
/// setzt genau die Funktion ein, die auch die Oberflaeche uebergibt.
void main() {
  List<SichererTreffer> finde(
    List<String> ordnernamen,
    List<Mandant> mandanten,
  ) => SichereTreffer.finde(
    offeneOrdner: [for (final name in ordnernamen) akte(name)],
    mandanten: mandanten,
    namensvorschlag: nameVorschlagAusOrdner,
  );

  final annaMeier = mandant(1, 'Meier', vorname: 'Anna');
  final karlSchmidt = mandant(2, 'Schmidt', vorname: 'Karl');

  group('SichereTreffer.finde', () {
    test('findet den genauen Vor- und Nachnamenstreffer', () {
      final treffer = finde(
        ['VUnfallursache Anna Meier'],
        [annaMeier, karlSchmidt],
      );

      expect(treffer, hasLength(1));
      expect(treffer.single.ordnername, 'VUnfallursache Anna Meier');
      expect(treffer.single.mandant, annaMeier);
    });

    // „Schmitt" und „Schmidt" liegen einen Tippfehler auseinander. Fuer den
    // Hinweis „Meinten Sie …?" reicht das; fuer eine Zuordnung ohne Rueckfrage
    // nicht.
    test('ein Tippfehler-Treffer ist kein sicherer Treffer', () {
      expect(finde(['VUnfallursache Karl Schmitt'], [karlSchmidt]), isEmpty);
    });

    test('zwei Vorschlaege sind kein sicherer Treffer', () {
      final annMeier = mandant(3, 'Meier', vorname: 'Ann');

      expect(
        finde(['VUnfallursache Anna Meier'], [annaMeier, annMeier]),
        isEmpty,
      );
    });

    // Ein Ordnername ist kein Fahrzeug: dass jemand dieses Kennzeichen haelt,
    // sagt nichts darueber, wessen Akte hier liegt. Gefragt wird deshalb ohne
    // Kennzeichen.
    test('ein reiner Kennzeichen-Treffer ist kein sicherer Treffer', () {
      final halter = mandant(
        4,
        'Weber',
        vorname: 'Karl',
        kennzeichen: ['HG-E 1427'],
      );

      expect(finde(['VUnfallursache HG-E 1427'], [halter]), isEmpty);
    });

    test('ein Ordner ohne beide Namensteile ist kein sicherer Treffer', () {
      expect(finde(['VUnfallursache Meier'], [annaMeier]), isEmpty);
      expect(finde(['Buchhaltung'], [annaMeier]), isEmpty);
    });

    test('ein Ordner ohne jeden Registerbezug bleibt liegen', () {
      expect(finde(['VUnfallursache Otto Fremd'], [annaMeier]), isEmpty);
    });

    test('ohne Register gibt es keine sicheren Treffer', () {
      expect(finde(['VUnfallursache Anna Meier'], const []), isEmpty);
    });
  });

  group('SichereTreffer.alsImportdatei', () {
    test('zwei Ordner desselben Mandanten ergeben eine Zeile', () {
      final treffer = finde(
        ['VUnfallursache Anna Meier', 'Strafsache Anna Meier'],
        [annaMeier],
      );

      final datei = SichereTreffer.alsImportdatei(treffer);

      expect(treffer, hasLength(2));
      expect(datei.mandanten, hasLength(1));
      expect(datei.mandanten.single.aktenOrdnernamen, [
        'VUnfallursache Anna Meier',
        'Strafsache Anna Meier',
      ]);
    });

    // Anschrift, E-Mail und Telefon bleiben leer, damit „Ergaenzen nie
    // ueberschreiben" gar nichts zu ueberschreiben versucht: der
    // Registereintrag weiss ueber sich selbst mehr als ein Ordnername.
    test('traegt Fassung 1, Quelle und Sicherheit — und keine Stammdaten', () {
      final vollstaendig = Mandant(
        id: 7,
        vorname: 'Anna',
        nachname: 'Meier',
        strasseHausnummer: 'Hauptstr. 1',
        postleitzahl: '61348',
        ort: 'Bad Homburg',
        emailAdresse: 'anna@example.org',
        telefonnummer: '06172 1234',
        notiz: 'Stammkundin',
        kennzeichen: const ['HG-E 1427'],
        erstelltAm: angelegt,
      );

      final datei = SichereTreffer.alsImportdatei(
        finde(['VUnfallursache Anna Meier'], [vollstaendig]),
      );
      final zeile = datei.mandanten.single;

      expect(datei.version, MandantenImportDatei.aktuelleVersion);
      expect(datei.version, 1);
      expect(datei.ohneMandantenbezug, isEmpty);
      expect(zeile.quelle, 'Ordnername');
      expect(zeile.sicherheit, 'hoch');
      expect(zeile.vorname, 'Anna');
      expect(zeile.nachname, 'Meier');
      expect(zeile.anrede, isEmpty);
      expect(zeile.strasseHausnummer, isEmpty);
      expect(zeile.postleitzahl, isEmpty);
      expect(zeile.ort, isEmpty);
      expect(zeile.emailAdresse, isEmpty);
      expect(zeile.telefonnummer, isEmpty);
      expect(zeile.notiz, isEmpty);
      expect(zeile.kennzeichen, isEmpty);
    });

    // Der Ordner heisst „Mueller", das Register kennt „Müller" — dieselbe
    // Person. Geschrieben wird die Fassung des Registers, sonst faende der
    // Import den vorhandenen Mandanten nicht wieder.
    test('die Schreibweise des Registers gewinnt', () {
      final mueller = mandant(5, 'Müller', vorname: 'Anna');

      final datei = SichereTreffer.alsImportdatei(
        finde(['VUnfallursache Anna Mueller'], [mueller]),
      );

      expect(datei.mandanten.single.nachname, 'Müller');
      expect(datei.mandanten.single.aktenOrdnernamen, [
        'VUnfallursache Anna Mueller',
      ]);
    });

    test('ohne Treffer entsteht eine Datei mit leerer Mandantenliste', () {
      final datei = SichereTreffer.alsImportdatei(const []);

      expect(datei.mandanten, isEmpty);
      expect(datei.version, MandantenImportDatei.aktuelleVersion);
    });
  });
}
