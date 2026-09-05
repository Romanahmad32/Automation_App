import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';
import 'package:automation_app/features/mandanten/presentation/utils/ordnername_vorschlag.dart';
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

    // Die echten Aktenordner der Kanzlei tragen **nur** den Nachnamen
    // („VUnfallursache Albrecht"), an 61 von 61 Ordnern des eingestellten
    // Stammordners belegt. Ein einzelnes Wort ist deshalb der Nachname —
    // andernfalls stünde bei jedem echten Ordner der Nachname im Vornamenfeld,
    // und „Sichere Treffer übernehmen" fände auf echten Daten nie etwas.
    test('ein einzelnes Wort wird zum Nachnamen', () {
      final vorschlag = nameVorschlagAusOrdner('VUnfallursache Albrecht');
      expect(vorschlag.vorname, isEmpty);
      expect(vorschlag.nachname, 'Albrecht');
    });

    test('nur ein Präfix ergibt keinen Vorschlag', () {
      final vorschlag = nameVorschlagAusOrdner('Strafsache');
      expect(vorschlag.vorname, isEmpty);
      expect(vorschlag.nachname, isEmpty);
    });
  });
}
