import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt, dass der Schriftgrad **ausschließlich** in der zentralen Skala
/// festgelegt wird (`lib/core/theme/presentation/`) und nirgendwo sonst als
/// `fontSize:` an einer Einzelstelle (Issue #57, 05.09.2026).
///
/// Anlass: Die Schrift war an vielen Stellen zu klein, und behoben wurde das
/// an einer einzigen Zahl — `Schriftskala.anhebung`. Eine zentral angehobene
/// Skala nützt aber nichts, solange Einzelstellen ihre Größe fest verdrahten:
/// Dann wächst nur ein Teil der Oberfläche mit, und das Ergebnis ist
/// schlechter als vorher. Vorher war alles gleichmäßig zu klein; nachher steht
/// eine 25-px-Überschrift neben einer 24-px-Überschrift und ein 15-px-Knopf
/// neben einem 16-px-Chip, ohne dass diese Unterschiede etwas bedeuten. Genau
/// diese drei Stellen gab es hier — die Seitenüberschrift der Vorlagen-Details
/// (`fontSize: 25`), der gefüllte Knopf im Theme (`fontSize: 15`) und zwei
/// nackte `TextStyle` in der Schrittleiste des Wizards.
///
/// Wie man es stattdessen macht: die passende **Rolle** aus
/// `Theme.of(context).textTheme` wählen — `bodyMedium` für Fließtext,
/// `labelLarge` für Beschriftungen von Knöpfen und Chips, `titleMedium` /
/// `titleLarge` für Sektions- und Seitentitel, `headlineSmall` für die
/// Überschrift einer Seite — und was daran abweichen soll, über
/// `copyWith(fontWeight: …, color: …)` setzen. Beides zusammen ergibt eine
/// Hierarchie, die auf einen Dreh an der Skala geschlossen reagiert.
///
/// Der Wächter ist bewusst grob: Er sucht das Wort, nicht seine Bedeutung. Das
/// reicht, weil `fontSize:` als benannter Parameter nur an einer Stelle
/// vorkommt — beim Festlegen einer Schriftgröße.
void main() {
  // Die Skala selbst und die Theme-Bausteine daneben dürfen Zahlen nennen;
  // das ist ihre Aufgabe. Alles andere holt sich die Rolle aus dem Theme.
  const erlaubtesVerzeichnis = 'lib/core/theme/presentation/';

  // Namentliche Ausnahmen außerhalb des Themes. Jede nennt ihren Grund — eine
  // neue kommt nur mit einem dazu (Vorbild: die `erlaubt`-Map in
  // zeichen_anzeige_test.dart).
  const ausnahmen = <String, String>{
    'lib/features/email_versand/presentation/widgets/signatur_ansicht.dart':
        'Grundschrift des HTML-Renders der Mail-Signatur — die Signatur '
        'bringt ihre eigenen Größen mit und soll beim Empfänger so aussehen, '
        'nicht wie die App.',
  };

  // `fontSize: 15`, aber nicht `fontSizeDelta:` und nicht `fontSizeFactor:` —
  // das sind die Stellschrauben der Skala, nicht eine feste Größe.
  final festeGroesse = RegExp(r'\bfontSize\s*:');

  test('kein fontSize ausserhalb der zentralen Schrift-Skala', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final pfad = relPfad(datei);
      if (pfad.startsWith(erlaubtesVerzeichnis)) continue;
      if (ausnahmen.containsKey(pfad)) continue;

      for (final zeile in datei.readAsLinesSync()) {
        // Kommentarzeilen zählen nicht: Wer erklärt, warum an einer Stelle
        // früher ein `fontSize:` stand, soll das hinschreiben dürfen.
        if (zeile.trimLeft().startsWith('//')) continue;
        if (festeGroesse.hasMatch(zeile)) {
          verstoesse.add('$pfad: ${zeile.trim()}');
        }
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Stellen verdrahten eine Schriftgröße fest und wachsen '
          'deshalb nicht mit Schriftskala.anhebung mit (Issue #57). Richtig '
          'ist: eine Rolle aus Theme.of(context).textTheme wählen '
          '(bodyMedium, labelLarge, titleMedium, headlineSmall …) und '
          'Abweichungen über copyWith(fontWeight: …, color: …) setzen. Trägt '
          'eine feste Größe an der Stelle fachlich, gehört die Datei mit '
          'Begründung in die Map `ausnahmen` in diesem Test — nicht der Test '
          'gelockert.\nVerletzende Stellen:\n  ${verstoesse.join('\n  ')}',
    );
  });

  // Ohne diesen zweiten Test verrottet die Ausnahmeliste still: Wird die
  // Datei umbenannt oder ihr fontSize entfernt, bleibt der Eintrag als
  // Freibrief für einen Pfad stehen, den es so nicht mehr gibt.
  test('die Ausnahmeliste hat keine Karteileichen', () {
    final ueberfluessig = <String>[];

    for (final eintrag in ausnahmen.entries) {
      final datei = File(eintrag.key);
      if (!datei.existsSync()) {
        ueberfluessig.add('${eintrag.key}: gibt es nicht mehr');
        continue;
      }
      if (!festeGroesse.hasMatch(datei.readAsStringSync())) {
        ueberfluessig.add(
          '${eintrag.key}: enthält gar kein fontSize mehr, Eintrag streichen',
        );
      }
    }
    ueberfluessig.sort();

    expect(
      ueberfluessig,
      isEmpty,
      reason:
          'Die Ausnahmeliste in schriftgroesse_test.dart ist nicht mehr '
          'aktuell:\n  ${ueberfluessig.join('\n  ')}',
    );
  });
}
