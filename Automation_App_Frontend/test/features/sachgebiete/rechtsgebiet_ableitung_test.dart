import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/services/rechtsgebiet_ableitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abteilung und Rechtsgebiet sind dieselbe Katalogzeile (§7.1) — hier steht,
/// wie die eine auf das andere führt, und wo sie bewusst nichts liefert.
void main() {
  const katalog = [
    Sachgebiet(
      id: 1,
      kuerzel: 'C01',
      name: 'Zivilrecht (allgemein)',
      // Der Vorschlag weicht hier vom Namen ab — genau dafür trägt der
      // Katalog ein eigenes Feld.
      rechtsgebietVorschlag: 'Zivilrecht',
      sortierung: 10,
      aktiv: true,
    ),
    Sachgebiet(
      id: 2,
      kuerzel: 'C03',
      name: 'Verkehrsrecht',
      rechtsgebietVorschlag: 'Verkehrsrecht',
      sortierung: 20,
      aktiv: true,
    ),
    Sachgebiet(
      id: 3,
      kuerzel: 'C05',
      name: 'Strafrecht',
      rechtsgebietVorschlag: 'Strafrecht',
      sortierung: 30,
      aktiv: true,
    ),
  ];

  test('nimmt den Rechtsgebiets-Vorschlag des Kürzels, nicht seinen Namen', () {
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, 'C01'), 'Zivilrecht');
  });

  test('folgt bei einer Überschneidung dem Hauptsachgebiet', () {
    // C05/3 ist Strafrecht mit Verkehrsbezug: Im Register (§6.2) steht es in
    // der Zeile „Strafrecht", nicht in „Verkehrsrecht".
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, 'C05/3'), 'Strafrecht');
  });

  test('verträgt Leerzeichen im Kürzel (§7.1 Normalisierung)', () {
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, 'C 03'), 'Verkehrsrecht');
  });

  test('liefert null statt Verkehrsrecht, wo nichts abzuleiten ist', () {
    // Der stillschweigende Rückfall auf den Schwerpunkt der Kanzlei wäre genau
    // die falsche Zeile im Register — deshalb „nichts", nicht „das Übliche".
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, 'C99'), isNull);
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, ''), isNull);
    expect(RechtsgebietAbleitung.zuAbteilung(katalog, null), isNull);
    expect(RechtsgebietAbleitung.zuAbteilung(const [], 'C03'), isNull);
  });
}
