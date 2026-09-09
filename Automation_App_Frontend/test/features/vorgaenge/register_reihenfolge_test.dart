import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Die Leserichtung der Registeransicht (§6.2).
///
/// Sie **stellt keine eigene Sortierung auf**, sondern liest die Folge des
/// Backends (`RegisterZeilenBau.Aus`) rückwärts. Wer an der Sortierung etwas
/// ändert, ändert weiterhin genau eine Stelle — im Dienst.
void main() {
  /// Wie das Backend liefert: Jahrgang aufsteigend, darin die laufende Nummer,
  /// Zeilen ohne Nummer hinten am Jahrgang.
  final bestand = [
    historieZeile(jahr: '2019', nummer: 9, zeichen: '09/19'),
    historieZeile(jahr: '2019', nummer: 10, zeichen: '10/19'),
    vorgangsZeile(jahr: '2026', nummer: 1, zeichen: '01/26'),
    vorgangsZeile(jahr: '2026', nummer: null, zeichen: 'ohne Nummer'),
  ];

  test('älteste zuerst lässt die Folge des Backends stehen', () {
    expect(
      RegisterReihenfolge.aeltesteZuerst
          .anwenden(bestand)
          .map((z) => z.zeichen),
      ['09/19', '10/19', '01/26', 'ohne Nummer'],
    );
  });

  /// Angesehen wird fast immer das Jüngste — nach tausenden übernommenen
  /// Zeilen stünde es sonst ganz unten. Ein laufender Vorgang ohne Nummer
  /// steht im Bestand hinten am Jahrgang und rückt damit ganz nach oben.
  test('neueste zuerst dreht die Folge um', () {
    expect(
      RegisterReihenfolge.neuesteZuerst.anwenden(bestand).map((z) => z.zeichen),
      ['ohne Nummer', '01/26', '10/19', '09/19'],
    );
  });

  test('die Vorgabe der Seite ist „neueste zuerst"', () {
    expect(RegisterReihenfolge.vorgabe, RegisterReihenfolge.neuesteZuerst);
  });
}
