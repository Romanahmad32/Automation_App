import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt die Regel aus CLAUDE.md: **keine privaten Typen und keine privaten
/// Top-Level-Funktionen** im Anwendungscode.
///
/// Hintergrund: ein privates `_WidgetXyz` ist ausserhalb seiner Datei kein
/// benennbarer Typ mehr. Es kann nicht wiederverwendet, nicht einzeln getestet
/// und nicht in einem anderen Feature erwaehnt werden — und weil es unsichtbar
/// ist, baut die naechste Aenderung daneben eine zweite Fassung davon. Genau
/// das soll die Regel verhindern.
///
/// Einzige Ausnahme: die `State`-Klasse eines `StatefulWidget`. Sie gehoert
/// untrennbar zu ihrem Widget, wird von `createState()` erzeugt und nie von
/// aussen benannt — das ist die uebliche Flutter-Konvention und steht so auch
/// in CLAUDE.md.
void main() {
  // Kopf einer Top-Level-Typdeklaration: ab Spalte 0, mit den Modifikatoren,
  // die Dart davorstellen darf, bis zum Rumpf ({) bzw. Abschluss (;). Die
  // Zeichenklasse schliesst Zeilenumbrueche ein, damit auch eine umbrochene
  // Deklaration ganz erfasst wird.
  final privaterTyp = RegExp(
    r'^(?:abstract\s+|base\s+|final\s+|sealed\s+|interface\s+|mixin\s+)*'
    r'(class|enum|mixin|extension|typedef)\s+(_\w+)([^{;]*)',
    multiLine: true,
  );

  // Top-Level-Funktion: Rueckgabetyp, dann ein Name mit Unterstrich, dann die
  // Parameterliste.
  //
  // Das erste Zeichen muss ein Wortzeichen in Spalte 0 sein, und zwischen
  // Rueckgabetyp und Namen sind nur Leerzeichen/Tabs erlaubt — kein `\s`.
  // Sonst frisst sich der Ausdruck ueber den Zeilenumbruch hinweg in die
  // Einrueckung der naechsten Zeile und meldet jede private *Methode* einer
  // Klasse als Verstoss. Private Methoden sind ausdruecklich erlaubt; die
  // Regel gilt nur fuer die oberste Ebene.
  final privateFunktion = RegExp(
    r'^[\w<>][\w<>,\[\]\? \t]*[ \t]+(_\w+)[ \t]*\(',
    multiLine: true,
  );

  test('keine privaten Typen ausser State-Klassen', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final inhalt = datei.readAsStringSync();
      for (final treffer in privaterTyp.allMatches(inhalt)) {
        final art = treffer.group(1)!;
        final name = treffer.group(2)!;
        final kopf = treffer.group(3)!;

        // `class _FooState extends State<Foo>` ist die zugelassene Ausnahme.
        if (art == 'class' && kopf.contains('extends State<')) continue;

        verstoesse.add('${relPfad(datei)}: $art $name');
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Private Typen sind ausserhalb ihrer Datei nicht benennbar und '
          'damit weder wiederverwendbar noch einzeln testbar. Die folgenden '
          'gehoeren als oeffentliche Klasse in eine eigene Datei '
          '(projektweit nutzbar unter lib/core/general_widgets/, sonst unter '
          'lib/features/<feature>/presentation/widgets/):\n  '
          '${verstoesse.join('\n  ')}',
    );
  });

  test('keine privaten Top-Level-Funktionen', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final inhalt = datei.readAsStringSync();
      for (final treffer in privateFunktion.allMatches(inhalt)) {
        verstoesse.add('${relPfad(datei)}: ${treffer.group(1)}()');
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Eine private Top-Level-Funktion ist aus keiner anderen Datei '
          'aufrufbar und wird deshalb beim naechsten Bedarf neu geschrieben '
          'statt wiederverwendet. Oeffentlich machen oder als Methode an den '
          'Typ haengen, zu dem sie gehoert:\n  ${verstoesse.join('\n  ')}',
    );
  });
}
