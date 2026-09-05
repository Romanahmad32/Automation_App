import 'package:automation_app/features/form_template_setup/domain/services/feld_abgleich.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Abgleich nach einem Dateiwechsel (#104, Stufe 3b): Welche Felder hat
/// die neue Word-Datei stehen lassen?
///
/// Die beiden wichtigsten Fälle stehen unten: **Bei unbekannter
/// Platzhalterliste wird nichts vorgeschlagen.** Der Vorschlag hier ist das
/// Löschen von Feldern — ein Ladezustand darf ihn nicht auslösen.
void main() {
  VorlagenStand stand({
    List<String>? platzhalter = const [],
    bool hatDatei = true,
    List<String?> feldnamen = const [],
  }) => VorlagenStand.bestimme(
    hatDateiOhne: hatDatei,
    hatDateiMit: false,
    platzhalterOhne: platzhalter,
    platzhalterMit: null,
    feldnamen: feldnamen,
  );

  test('ein Feld, dessen Platzhalter weggefallen ist, wird gemeldet', () {
    const feldnamen = ['Kennzeichen', 'Frist'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(
        platzhalter: ['Kennzeichen', 'Frist'],
        feldnamen: feldnamen,
      ),
      nachher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
    );

    expect(verschwunden, ['Frist']);
  });

  test('ein neu hinzugekommener Platzhalter ist kein Befund für diesen '
      'Abgleich', () {
    // Der gehört in „Platzhalter ohne Feld" (VorlagenStand) — hier geht es
    // ausschließlich um Felder, die ins Leere laufen.
    const feldnamen = ['Kennzeichen'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
      nachher: stand(
        platzhalter: ['Kennzeichen', 'Zeichen'],
        feldnamen: feldnamen,
      ),
    );

    expect(verschwunden, isEmpty);
  });

  test('ein Feld, das schon vorher nirgends ankam, ist kein Verlust dieses '
      'Wechsels', () {
    // Es steht ohnehin als Warnung an seiner Zeile; hier noch einmal gefragt
    // zu werden, verwechselte den alten Befund mit einer Folge des Wechsels.
    const feldnamen = ['Kennzeichen', 'Tippfehler'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
      nachher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
    );

    expect(verschwunden, isEmpty);
  });

  test('verglichen wird ohne Groß-/Kleinschreibung, gemeldet in der '
      'Schreibweise des Feldes', () {
    const feldnamen = ['Kennzeichen'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(platzhalter: ['KENNZEICHEN'], feldnamen: feldnamen),
      nachher: stand(platzhalter: ['Unfalltag'], feldnamen: feldnamen),
    );

    expect(verschwunden, ['Kennzeichen']);
  });

  test('jeder Name nur einmal, in der Reihenfolge der Felder', () {
    const feldnamen = ['Frist', 'Kennzeichen', ' frist ', null, ''];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(
        platzhalter: ['Frist', 'Kennzeichen'],
        feldnamen: feldnamen,
      ),
      nachher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
    );

    expect(verschwunden, ['Frist']);
  });

  test('ist die Liste nachher unbekannt, wird nichts vorgeschlagen', () {
    const feldnamen = ['Kennzeichen'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(platzhalter: ['Kennzeichen'], feldnamen: feldnamen),
      // Die neue Datei ist verknüpft, aber noch nicht gelesen.
      nachher: stand(platzhalter: null, feldnamen: feldnamen),
    );

    expect(verschwunden, isEmpty);
  });

  test('war vorher keine Datei da, hat auch nichts sein Vorkommen '
      'verloren', () {
    const feldnamen = ['Kennzeichen'];

    final verschwunden = FeldAbgleich.verschwundeneFelder(
      feldnamen: feldnamen,
      vorher: stand(hatDatei: false, platzhalter: null, feldnamen: feldnamen),
      nachher: stand(platzhalter: ['Unfalltag'], feldnamen: feldnamen),
    );

    expect(verschwunden, isEmpty);
  });
}
