import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';
import 'doku_verweise.dart';

/// Haelt die Anforderungsverweise in Kommentaren und Doku an der geltenden
/// Gliederung.
///
/// `REQUIREMENTS.md` ist absichtlich nicht versioniert, ihre Gliederung aber
/// schon: [`docs/ANFORDERUNGEN_INDEX.md`]. Verweise wie `§4.8` sind damit
/// pruefbar — und das ist noetig, weil sie sonst geraeuschlos veralten: das
/// Dokument wurde einmal umgegliedert, danach zeigten rund fuenfzig Kommentare
/// in beiden Sprachen auf Nummern, die es nicht mehr gab. Ein falscher
/// Paragraphenverweis ist schlimmer als keiner: er sieht aus wie eine Quelle.
///
/// Schreibweise: **`§4.8` ohne Leerzeichen** meint diese Anforderungen.
/// Gesetzesstellen tragen eins (`§ 13 RVG`, `§ 203 BGB`) und bleiben
/// unangetastet — daran unterscheidet der Test beide.
void main() {
  final index = File('../docs/ANFORDERUNGEN_INDEX.md');

  if (!index.existsSync()) {
    test('der Anforderungs-Index ist vorhanden', () {
      fail(
        'docs/ANFORDERUNGEN_INDEX.md fehlt. Ohne sie sind die Paragraphen'
        'verweise im Code nicht pruefbar — und REQUIREMENTS.md liegt im Klon '
        'nicht vor.',
      );
    });
    return;
  }

  final indexText = index.readAsStringSync();
  final gueltig = <String>{
    // Kapitelueberschriften: "### 4 Kernworkflow …"
    for (final treffer in RegExp(
      r'^#{2,3} (\d+) ',
      multiLine: true,
    ).allMatches(indexText))
      treffer.group(1)!,
    // Tabellenzeilen: "| 4.8 | Auftragsabschluss …"
    for (final treffer in RegExp(
      r'^\|\s*(\d+\.\d+)\s*\|',
      multiLine: true,
    ).allMatches(indexText))
      treffer.group(1)!,
  };

  /// Alle Dateien, in denen ein Anforderungsverweis stehen kann.
  List<File> quellen() => [
    ...dartQuelldateien('lib'),
    for (final pfad in [
      '../CLAUDE.md',
      'CLAUDE.md',
      '../AutomationService/CLAUDE.md',
      ...markdownUnter('lib/features'),
      ...markdownUnter('../docs'),
      ...markdownUnter('../.claude'),
    ])
      File(pfad),
  ];

  test('der Index nennt ueberhaupt Paragraphen', () {
    // Ein leeres Sollverzeichnis wuerde jeden Verweis durchwinken.
    expect(gueltig.length, greaterThan(20), reason: 'Index nicht lesbar?');
  });

  test('jeder Paragraphenverweis steht im Anforderungs-Index', () {
    final verweis = RegExp(r'§(\d+(?:\.\d+)?)');
    final unbekannt = <String>[];

    for (final datei in quellen()) {
      if (!datei.existsSync()) continue;
      for (final treffer in verweis.allMatches(datei.readAsStringSync())) {
        final nummer = treffer.group(1)!;
        if (!gueltig.contains(nummer)) {
          unbekannt.add('${normalisiert(datei.path)} -> §$nummer');
        }
      }
    }
    unbekannt.sort();

    expect(
      unbekannt.toSet().toList(),
      isEmpty,
      reason:
          'Diese Paragraphen gibt es in der geltenden Gliederung nicht:\n  '
          '${unbekannt.toSet().join('\n  ')}\n'
          'Richtige Nummer aus docs/ANFORDERUNGEN_INDEX.md nachtragen. Ist die '
          'Gliederung selbst gewachsen, gehoert der Index zuerst nachgezogen.',
    );
  });

  test('kein Verweis in der alten Schreibweise', () {
    final alt = RegExp(r'(Req\.?|Requirement|Anforderung)\s+\d');
    final treffer = <String>[];

    for (final datei in quellen()) {
      if (!datei.existsSync()) continue;
      final zeilen = datei.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (alt.hasMatch(zeilen[i])) {
          treffer.add('${normalisiert(datei.path)}:${i + 1}');
        }
      }
    }
    treffer.sort();

    expect(
      treffer,
      isEmpty,
      reason:
          'Anforderungen werden als `§4.8` zitiert, nicht als "Req. 3.2":\n  '
          '${treffer.join('\n  ')}\n'
          'Die alte Schreibweise stammt aus einer frueheren Gliederung und '
          'laesst sich nicht gegen den Index pruefen.',
    );
  });
}
