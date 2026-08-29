import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt die Längenobergrenze für handgeschriebene Dart-Dateien aus
/// CLAUDE.md: höchstens **250 Anweisungszeilen** und **450 Zeilen insgesamt**.
///
/// Gezählt wird an [anweisungszeilen], also **ohne** Kommentare und
/// Leerzeilen. Das ist eine bewusste Korrektur der früheren Fassung
/// („Richtwert 250, hart 300", roh gezählt): die zählte das Erklären als
/// Kosten — ausgerechnet in einer Codebasis, deren größter Vorteil ist, dass
/// ihre Kommentare das *Warum* festhalten. Praktisch führte sie dazu, dass
/// jemand eine Datei aufteilte, um ein paar Zeilen *hinzuzufügen*: der Schnitt
/// kam dann aus der Zählung, nicht aus dem Entwurf. Und sie war zur
/// Dauerausnahme geworden — elf Dateien lagen zwischen 250 und 300.
///
/// Die zweite Grenze fängt, was die erste durchließe: eine Datei aus tausend
/// Zeilen Kommentar ist trotzdem nichts, was man überblickt.
///
/// Generierte Dateien sind ausgenommen (siehe [generierteEndungen]).
void main() {
  const maxAnweisungen = 250;
  const maxRoh = 450;

  /// Dateien, die bei der Umstellung schon über der Grenze lagen, mit ihrem
  /// damaligen Stand als Obergrenze: sie dürfen nur noch schrumpfen.
  ///
  /// Beide sind große Formularseiten mit wenig Kommentar — die Regel zeigt
  /// hier also richtig hin. Sie stehen namentlich hier statt hinter einem
  /// hochgesetzten Limit, damit sichtbar bleibt, dass es Schulden sind und wie
  /// viele. Wer eine davon aufteilt, streicht ihre Zeile — so geschehen mit
  /// `vorgang_starten_form_view.dart`, aus der `MandantEntscheidung` heraus-
  /// geschnitten wurde.
  const altlasten = <String, int>{
    'lib/features/form_template_setup/presentation/pages/form_template_details_page.dart':
        263,
    'lib/features/mandanten/presentation/pages/mandant_details_page.dart': 279,
  };

  int grenzeFuer(String pfad) => altlasten[pfad] ?? maxAnweisungen;

  // Einmal durchlaufen statt fünfmal: Der rekursive Verzeichnisdurchlauf samt
  // Sortierung ist der teuerste Teil dieser Datei, und alle drei Tests brauchen
  // dieselbe Liste. `late` hält ihn aus der Sammelphase heraus — er läuft erst,
  // wenn der erste Test ihn anfasst, und sein Hinweis auf das falsche
  // Arbeitsverzeichnis bleibt damit ein Testfehler statt eines Ladefehlers.
  late final quellen = dartQuelldateien('lib');

  test('keine Dart-Datei überschreitet $maxAnweisungen Anweisungszeilen', () {
    final verstoesse = <String>[];
    for (final datei in quellen) {
      final pfad = relPfad(datei);
      final zeilen = anweisungszeilen(datei);
      if (zeilen > grenzeFuer(pfad)) {
        verstoesse.add('$pfad ($zeilen Anweisungszeilen)');
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Eine Datei soll höchstens $maxAnweisungen Zeilen Code tragen '
          '(Kommentare und Leerzeilen zählen nicht mit):\n  '
          '${verstoesse.join('\n  ')}\n'
          'Was darüber liegt, gehört in eigenständige Widgets/Klassen '
          'aufgeteilt — nicht in weniger Kommentare.',
    );
  });

  test('keine Dart-Datei überschreitet $maxRoh Zeilen insgesamt', () {
    final verstoesse = <String>[];
    for (final datei in quellen) {
      final zeilen = datei.readAsLinesSync().length;
      if (zeilen > maxRoh) verstoesse.add('${relPfad(datei)} ($zeilen Zeilen)');
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Auch mit vielen Kommentaren bleibt eine Datei unter $maxRoh '
          'Zeilen:\n  ${verstoesse.join('\n  ')}\n'
          'Wird sie länger, ist nicht der Kommentar zu viel, sondern der '
          'Gegenstand zu groß.',
    );
  });

  test('die Altlastenliste hat keine Karteileichen', () {
    // Eine Ausnahme, die niemand mehr braucht, ist eine Ausnahme, die
    // stillschweigend wieder Luft schafft.
    final nachPfad = {for (final datei in quellen) relPfad(datei): datei};
    final ueberfluessig = <String>[];
    for (final eintrag in altlasten.entries) {
      final datei = nachPfad[eintrag.key];
      if (datei == null) {
        ueberfluessig.add('${eintrag.key}: gibt es nicht mehr');
        continue;
      }
      final ist = anweisungszeilen(datei);
      if (ist <= maxAnweisungen) {
        ueberfluessig.add(
          '${eintrag.key}: nur noch $ist Anweisungszeilen, Eintrag streichen',
        );
      } else if (ist < eintrag.value) {
        ueberfluessig.add(
          '${eintrag.key}: auf $ist geschrumpft, Obergrenze nachziehen '
          '(steht auf ${eintrag.value})',
        );
      }
    }
    ueberfluessig.sort();

    expect(
      ueberfluessig,
      isEmpty,
      reason:
          'Die Altlastenliste in file_length_test.dart ist nicht mehr '
          'aktuell:\n  ${ueberfluessig.join('\n  ')}',
    );
  });
}
