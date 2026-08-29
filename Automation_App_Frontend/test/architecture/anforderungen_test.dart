import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';
import 'doku_verweise.dart';

/// Haelt die Anforderungsverweise in Kommentaren und Doku an der geltenden
/// Gliederung.
///
/// Geprueft wird in zwei Schritten, und keiner der beiden reicht allein:
///
/// 1. **Verweis gegen Index.** Jedes `§4.8` im Code und in der Doku muss in
///    [`docs/ANFORDERUNGEN_INDEX.md`] stehen. Noetig, weil solche Verweise
///    sonst geraeuschlos veralten: Das Dokument wurde einmal umgegliedert,
///    danach zeigten rund fuenfzig Kommentare in beiden Sprachen auf Nummern,
///    die es nicht mehr gab. Ein falscher Paragraphenverweis ist schlimmer als
///    keiner — er sieht aus wie eine Quelle.
/// 2. **Index gegen Dokument.** Der Index wird von Hand gepflegt. Schritt 1
///    allein bliebe also gruen, waehrend Index und Verweise gemeinsam veralten
///    und geschlossen auf eine Gliederung zeigen, die es nicht mehr gibt.
///    Deshalb haelt der zweite Test die Nummern des Index gegen die
///    Ueberschriften in `REQUIREMENTS.md`.
///
/// Die Verweise ueber den Index laufen zu lassen statt direkt gegen das
/// Dokument ist Absicht: So muss eine neue Nummer einmal bewusst nachgezogen
/// werden, statt sich stillschweigend mitzuaendern — und der Index bleibt fuer
/// sich lesbar, als Einstieg ohne den Volltext.
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
        'verweise im Code nicht pruefbar.',
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

  test('der Index deckt sich mit der Gliederung in REQUIREMENTS.md', () {
    final dokument = File('../REQUIREMENTS.md');
    expect(
      dokument.existsSync(),
      isTrue,
      reason:
          'REQUIREMENTS.md fehlt im Wurzelverzeichnis. Sie ist versioniert — '
          'fehlt sie, stimmt etwas mit dem Klon nicht.',
    );

    final text = dokument.readAsStringSync();
    final imDokument = <String>{
      // "## 4. Kernworkflow …" — die Kapitelnummer traegt im Dokument einen
      // Punkt, im Index ("### 4 Kernworkflow …") keinen.
      for (final treffer in RegExp(
        r'^## (\d+)\. ',
        multiLine: true,
      ).allMatches(text))
        treffer.group(1)!,
      // "### 4.10 Erstkontakt ueber die Kanzlei-Website"
      for (final treffer in RegExp(
        r'^### (\d+\.\d+) ',
        multiLine: true,
      ).allMatches(text))
        treffer.group(1)!,
    };

    // Nach Zahlen ordnen, nicht nach Zeichen: sonst stuende 4.10 vor 4.2.
    int nachNummer(String a, String b) {
      final links = a.split('.').map(int.parse).toList();
      final rechts = b.split('.').map(int.parse).toList();
      for (var i = 0; i < links.length && i < rechts.length; i++) {
        if (links[i] != rechts[i]) return links[i].compareTo(rechts[i]);
      }
      return links.length.compareTo(rechts.length);
    }

    final abweichungen = <String>[
      for (final nummer
          in imDokument.difference(gueltig).toList()..sort(nachNummer))
        '§$nummer steht in REQUIREMENTS.md, fehlt aber im Index',
      for (final nummer
          in gueltig.difference(imDokument).toList()..sort(nachNummer))
        '§$nummer steht im Index, gibt es in REQUIREMENTS.md aber nicht',
    ];

    expect(
      abweichungen,
      isEmpty,
      reason:
          'Index und Anforderungsdokument sind auseinandergelaufen:\n  '
          '${abweichungen.join('\n  ')}\n'
          'docs/ANFORDERUNGEN_INDEX.md ist das Inhaltsverzeichnis von '
          'REQUIREMENTS.md. Laeuft es hinterher, pruefen die Verweise oben '
          'gegen eine Gliederung, die es nicht mehr gibt — und bleiben dabei '
          'gruen. Den Index nachziehen, nicht diesen Test.',
    );
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
