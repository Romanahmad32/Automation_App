import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_zuordnung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Abgleich zwischen Feldname und Platzhalter (#36): Wer keinen Partner
/// hat, bekommt einen vorgeschlagen — statt eines zweiten Feldes, das der
/// Anwalt zusätzlich tippt und das doch ins Leere geht.
void main() {
  List<String> namenVon(List<ZuordnungsVorschlag> vorschlaege) =>
      vorschlaege.map((vorschlag) => vorschlag.name).toList();

  test('gleiche Schreibweise bis auf Bindestrich ist der sicherste Fall', () {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      'VersicherungsscheinNr',
      const ['Kennzeichen', 'Versicherungsschein-Nr'],
    );

    expect(namenVon(vorschlaege), ['Versicherungsschein-Nr']);
    expect(vorschlaege.single.guete, ZuordnungsGuete.schreibweise);
    expect(vorschlaege.single.tauschtWaise, isFalse);
  });

  test('ein reiner Groß-/Kleinschreibungsunterschied ist kein Fund — die '
      'beiden treffen sich beim Erzeugen ohnehin', () {
    expect(
      PlatzhalterZuordnung.vorschlaege('Zahlungsfrist', const [
        'zahlungsfrist',
      ]),
      isEmpty,
    );
  });

  test('ein Name, der im anderen steckt, ist ein Vorschlag', () {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      'Verkehrsunfalldatum',
      const ['Kennzeichen', 'Unfalldatum'],
    );

    expect(namenVon(vorschlaege), ['Unfalldatum']);
    expect(vorschlaege.single.guete, ZuordnungsGuete.teilname);
  });

  test('zu kurz zum Stecken: "Ort" trifft sonst jedes zweite Feld', () {
    expect(
      PlatzhalterZuordnung.vorschlaege('Ort', const ['Wohnort', 'Vorortermin']),
      isEmpty,
    );
    expect(
      PlatzhalterZuordnung.vorschlaege('Frist', const ['Zahlungsfrist']),
      hasLength(1),
    );
  });

  test('ohne Zusammenhang bleibt es still', () {
    expect(
      PlatzhalterZuordnung.vorschlaege('Zeichen', const [
        'Mandant',
        'Betrag',
        '',
      ]),
      isEmpty,
    );
  });

  test('die sicherere Güte steht vorn', () {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege('Unfalldatum', const [
      'Verkehrsunfalldatum',
      'Unfall-Datum',
    ]);

    expect(namenVon(vorschlaege), ['Unfall-Datum', 'Verkehrsunfalldatum']);
  });

  test('ein Kandidat, der schon einen Platzhalter trifft, tauscht nur den '
      'Waisen — Befund statt Angebot, und ans Ende', () {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      'Verkehrsunfalldatum',
      const ['Unfalldatum', 'Unfall-Datum'],
      // Die Auflistungs-Datei nennt dieselbe Angabe anders; das Feld
      // "Unfalldatum" kommt dort an und darf nicht weggenommen werden.
      // "Unfall-Datum" trifft dagegen nichts — die Ersetzung kennt nur
      // IgnoreCase, kein Bindestrich-Erbarmen — und ist der richtige Kandidat.
      belegtePlatzhalter: const ['Unfalldatum', 'Gegnerkennzeichen'],
    );

    expect(namenVon(vorschlaege), ['Unfall-Datum', 'Unfalldatum']);
    expect(vorschlaege.first.tauschtWaise, isFalse);
    expect(vorschlaege.last.tauschtWaise, isTrue);
  });

  test('Doppelte zählen einmal — beide Word-Dateien können denselben '
      'Platzhalter liefern', () {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      'Verkehrsunfalldatum',
      const ['Unfalldatum', 'unfalldatum'],
    );

    expect(namenVon(vorschlaege), ['Unfalldatum']);
  });
}
