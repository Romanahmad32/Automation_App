import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Hält die Auswahlmarkierung an ihrer **Form** fest: Was ausgewählt ist, trägt
/// ein Häkchen — nicht nur eine andere Hintergrundfarbe.
///
/// Anlass war der Speicherschritt der Word-Automation. Dort stand
/// `showSelectedIcon: false` an der Auswahl „Was abgelegt wird", und damit trug
/// der gewählte Zustand allein die Füllung: im Kanzlei-Design `#EFE7E1` auf
/// `#FBF8F4`, gemessen 1,17:1. Rund drei Prozent Helligkeitsunterschied,
/// unter jeder Kontrastschwelle und für farbfehlsichtige Nutzer gar nicht
/// vorhanden. Wer nicht sieht, ob „Word", „PDF" oder „Word + PDF" gewählt ist,
/// legt die falsche Fassung ab und merkt es erst in der Akte.
///
/// Material zeigt das Häkchen von sich aus. Der Fehler entsteht nicht dadurch,
/// dass jemand etwas vergisst, sondern dadurch, dass jemand es abschaltet —
/// meist, weil das Häkchen die Schaltfläche breiter macht. Genau diese eine
/// Zeile fängt dieser Test; die Farbseite der Regel steht zentral in
/// `lib/core/theme/presentation/auswahl_themes.dart` und wird von
/// `test/core/theme/auswahl_themes_test.dart` geprüft.
///
/// Es gibt dafür keine Ausnahmeliste. Braucht eine Stelle wirklich keine Form,
/// gehört das begründet hierher — und nicht still in die Widget-Datei.
void main() {
  // `showSelectedIcon` gehört dem SegmentedButton, `showCheckmark` den Chips.
  final abgeschaltet = RegExp(r'show(?:SelectedIcon|Checkmark):\s*false');

  /// Die begründeten Ausnahmen, je Datei mit ihrem Grund.
  ///
  /// Ein Eintrag hier ist **kein Muster zum Nachmachen**, sondern der
  /// Einzelfall, in dem das Häkchen mehr kaputt macht, als es trägt — und er
  /// muss sagen, was die Auswahl stattdessen sichtbar macht. Wer eine Stelle
  /// einträgt, weil das Häkchen dort „stört", hat den falschen Eintrag: Dann
  /// stimmt das Layout nicht, nicht die Regel.
  const ausnahmen = <String, String>{
    'lib/features/settings/presentation/widgets/einstellungen_aktionszeile.dart':
        'Abschnittswahl der Einstellungen. Material ersetzt beim gewählten '
        'Chip das Symbol durch das Häkchen — hier ist dieses Symbol aber die '
        'Kennung des Abschnitts (Haus, Tabelle, Briefumschlag, …). Von sechs '
        'Symbolen verschwände immer genau das eine, das man gerade ansieht. '
        'Die Auswahl trägt stattdessen der Rahmen in der Primärfarbe: 1,5 px '
        'gegen 1 px in blassem outlineVariant, also ein Unterschied in '
        'Stärke und Farbe, der auch ohne Farbsehen bleibt.',
  };

  test('kein Widget schaltet das Häkchen der Auswahl ab', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      if (ausnahmen.containsKey(relPfad(datei))) continue;
      final zeilen = datei.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (abgeschaltet.hasMatch(zeilen[i])) {
          verstoesse.add('${relPfad(datei)}:${i + 1}: ${zeilen[i].trim()}');
        }
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Ohne Häkchen trägt der ausgewählte Zustand allein die Füllfarbe — '
          'im Kanzlei-Design 1,17:1 gegen den Untergrund und für '
          'farbfehlsichtige Nutzer gar kein Unterschied. Die Zeile ersatzlos '
          'streichen; Material zeigt das Häkchen dann von sich aus:\n  '
          '${verstoesse.join('\n  ')}',
    );
  });

  // Eine Ausnahmeliste, die niemand prüft, wächst und veraltet still: Wer die
  // abschaltende Zeile entfernt, lässt den Eintrag stehen, und die nächste
  // Änderung an derselben Datei fällt wieder durch das Netz.
  test('jede Ausnahme wird noch gebraucht', () {
    final unnoetig = <String>[];

    for (final pfad in ausnahmen.keys) {
      final datei = File(pfad);
      if (!datei.existsSync()) {
        unnoetig.add('$pfad — die Datei gibt es nicht mehr');
      } else if (!datei.readAsLinesSync().any(abgeschaltet.hasMatch)) {
        unnoetig.add('$pfad — schaltet das Häkchen gar nicht mehr ab');
      }
    }

    expect(
      unnoetig,
      isEmpty,
      reason:
          'Diese Einträge in `ausnahmen` sind gegenstandslos und gehören '
          'gestrichen:\n  ${unnoetig.join('\n  ')}',
    );
  });
}
