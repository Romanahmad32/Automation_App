import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_art_ableitung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Welche Vorlage zu welchem Vorgang passt (§4.11, §7.1). Der Katalog hier ist
/// der des Dienstes (`SachgebietEntityConfiguration`), Zeile für Zeile.
void main() {
  const zeilen = [
    ('C01', 'Zivilrecht (allgemein)', 'Zivilrecht', null),
    ('C01a', 'Arbeitsrecht', 'Arbeitsrecht', null),
    ('C02', 'Familienrecht', 'Familienrecht', null),
    ('C03', 'Verkehrsrecht', 'Verkehrsrecht', VollmachtArt.unfallsachen),
    (
      'C03o',
      'Ordnungswidrigkeitssache',
      'Ordnungswidrigkeitssache',
      VollmachtArt.bussgeldsachen,
    ),
    (
      'C04',
      'Verkehrsstrafrecht',
      'Verkehrsstrafrecht',
      VollmachtArt.strafsache,
    ),
    ('C05', 'Strafrecht', 'Strafrecht', VollmachtArt.strafsache),
    ('C06', 'Verwaltungsrecht', 'Verwaltungsrecht', null),
    ('C06a', 'Ausländer- und Asylrecht', 'Ausländer- und Asylrecht', null),
    ('C06s', 'Sozialrecht', 'Sozialrecht', null),
    ('C07', 'Sonstiges', 'Sonstiges', null),
    ('C07m', 'Markenrecht', 'Markenrecht', null),
  ];

  final katalog = [
    for (final (index, (kuerzel, name, vorschlag, _)) in zeilen.indexed)
      Sachgebiet(
        id: index + 1,
        kuerzel: kuerzel,
        name: name,
        rechtsgebietVorschlag: vorschlag,
        sortierung: index,
        aktiv: true,
      ),
  ];

  group('jede Katalogzeile', () {
    for (final (kuerzel, _, vorschlag, erwartet) in zeilen) {
      test('$kuerzel „$vorschlag" → ${erwartet?.titel ?? 'keine'}', () {
        expect(
          VollmachtArtAbleitung.zuVorgang(
            katalog,
            rechtsgebiet: vorschlag,
            abteilung: kuerzel,
          ),
          erwartet,
        );
      });
    }
  });

  test('Strafrecht mit Verkehrsbezug (C05/3) ist eine Strafsache', () {
    expect(VollmachtArtAbleitung.zuKuerzel('C05/3'), VollmachtArt.strafsache);
  });

  test('der kleingeschriebene Altbestand trifft den Katalog', () {
    expect(
      VollmachtArtAbleitung.zuVorgang(katalog, rechtsgebiet: 'verkehrsrecht'),
      VollmachtArt.unfallsachen,
    );
  });

  test('ein von Hand gesetztes Rechtsgebiet schlägt die Abteilung', () {
    expect(
      VollmachtArtAbleitung.zuVorgang(
        katalog,
        rechtsgebiet: 'Zivilrecht',
        abteilung: 'C03',
      ),
      isNull,
      reason: 'Wer das Rechtsgebiet abweichend setzt, meint die Sache.',
    );
  });

  test('ohne Katalog oder ohne Rechtsgebiet zählt die Abteilung', () {
    expect(
      VollmachtArtAbleitung.zuVorgang(
        const [],
        rechtsgebiet: 'Strafrecht',
        abteilung: 'C03o',
      ),
      VollmachtArt.bussgeldsachen,
    );
    expect(
      VollmachtArtAbleitung.zuVorgang(
        katalog,
        rechtsgebiet: '',
        abteilung: 'C04',
      ),
      VollmachtArt.strafsache,
    );
  });

  test('ohne alles gibt es keine Vorbelegung — nie still Unfallsachen', () {
    expect(VollmachtArtAbleitung.zuVorgang(katalog, rechtsgebiet: ''), isNull);
  });
}
