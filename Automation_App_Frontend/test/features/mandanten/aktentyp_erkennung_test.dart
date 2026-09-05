import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/services/ordnername_vorschlag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AktentypErkennung', () {
    test('erkennt die uneinheitlichen Verkehrsunfall-Schreibweisen', () {
      for (final name in [
        'VUnfallursache Mark',
        'VUnvallursache Saeed Ahmad',
        'VerkUnfursache Max Bein',
        'Verkehrsunfallsache Anna Klein',
      ]) {
        expect(
          AktentypErkennung.typVon(name),
          Aktentyp.verkehrsunfall,
          reason: name,
        );
      }
    });

    test('erkennt die Sachgebiete, die nicht zugeordnet werden müssen', () {
      expect(AktentypErkennung.typVon('Bußgeldsache X'), Aktentyp.bussgeld);
      expect(AktentypErkennung.typVon('Owi Y'), Aktentyp.bussgeld);
      expect(AktentypErkennung.typVon('Strafsache Mark'), Aktentyp.straf);
      expect(AktentypErkennung.typVon('StrSache Saeed'), Aktentyp.straf);
      expect(
        AktentypErkennung.typVon('FamSache Mark Müller'),
        Aktentyp.familie,
      );
    });

    // Der wichtigste Fall: ein Ordner ohne Präfix kann sehr wohl eine
    // Verkehrsunfallsache sein und darf deshalb nicht weggefiltert werden.
    test('ordner ohne Präfix bleiben Unfallkandidaten', () {
      final typ = AktentypErkennung.typVon('Max Mustermann');
      expect(typ, Aktentyp.ohnePraefix);
      expect(typ.istUnfallkandidat, isTrue);
      expect(Aktentyp.verkehrsunfall.istUnfallkandidat, isTrue);
      expect(Aktentyp.bussgeld.istUnfallkandidat, isFalse);
    });

    test('ohne Rücksicht auf Groß- und Kleinschreibung', () {
      expect(
        AktentypErkennung.typVon('vunfallursache mark'),
        Aktentyp.verkehrsunfall,
      );
    });

    test('liefert das erkannte Präfix in der Schreibweise der Tabelle', () {
      expect(
        AktentypErkennung.erkenne('vunfallursache mark').praefix,
        'VUnfallursache',
      );
      expect(AktentypErkennung.erkenne('Max Mustermann').praefix, isEmpty);
    });
  });

  group('nameVorschlagAusOrdner', () {
    test('streift dasselbe Präfix ab, nach dem gefiltert wird', () {
      final vorschlag = nameVorschlagAusOrdner('VUnfallursache Mark Müller');
      expect(vorschlag.vorname, 'Mark');
      expect(vorschlag.nachname, 'Müller');
    });

    test('lässt unbekannte Ordnernamen unverändert', () {
      final vorschlag = nameVorschlagAusOrdner('Max Mustermann');
      expect(vorschlag.vorname, 'Max');
      expect(vorschlag.nachname, 'Mustermann');
    });

    // Diese Erwartung war bis zum 05.09.2026 umgekehrt („ein einzelnes Wort
    // wird zum Vornamen") und wurde auf ausdrücklichen Auftrag gedreht — nicht,
    // um einen roten Test grün zu bekommen, sondern weil sie den Aktenbestand
    // falsch beschrieb: `docs/MANDANTEN_IMPORT.md` führt den Mandanten „Mark
    // Schmidt" mit den Ordnern „VUnfallursache Schmidt" und „Bußgeldsache
    // Schmidt". Das einzelne Wort hinter dem Präfix ist in dieser Kanzlei der
    // Nachname. Als Vorname gelesen fand der Vorschlag im Register nie einen
    // Treffer, weil `MandantErkennung` am Nachnamen wiedererkennt — und genau
    // darauf baut die Beschriftung der Arbeitspakete (Issue #108).
    test('ein einzelnes Wort ist der Nachname', () {
      final vorschlag = nameVorschlagAusOrdner('Strafsache Schmidt');
      expect(vorschlag.vorname, isEmpty);
      expect(vorschlag.nachname, 'Schmidt');
    });

    test('nur ein Präfix ergibt keinen Vorschlag', () {
      final vorschlag = nameVorschlagAusOrdner('Strafsache');
      expect(vorschlag.vorname, isEmpty);
      expect(vorschlag.nachname, isEmpty);
    });
  });
}
