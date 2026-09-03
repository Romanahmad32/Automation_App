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

  test('kein Widget schaltet das Häkchen der Auswahl ab', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
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
}
