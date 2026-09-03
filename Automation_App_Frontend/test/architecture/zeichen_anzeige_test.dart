import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Hält die Oberfläche am **Zeichen** fest — „216/26 C03", nicht an der vollen
/// Referenz „216/26 C03_EU-FE 1111".
///
/// Beides bezeichnet denselben Vorgang, aber nur das Zeichen ist die Sprache
/// der Kanzlei; das angehängte Kennzeichen trägt allein die maschinelle
/// Zuordnung der Zentralruf-Antwort (§4.2). Vor diesem Test war die Regel
/// nirgends aufgeschrieben, und das Ergebnis war einheitlich falsch: Kacheln,
/// Auswahllisten und Dialogtitel zeigten durchweg die Referenz. Ohne Wächter
/// wandert die nächste neue Anzeigestelle genauso wieder dorthin zurück —
/// `vorgang.referenz` ist der naheliegende Griff, und niemand sieht der Zeile
/// an, dass sie eine Entscheidung trifft.
///
/// Angezeigt wird über [ZeichenText] bzw. `vorgang.zeichen` /
/// `ReferenzTeile.zeichenAus(referenz)`.
///
/// **Bewusst eng.** Geprüft werden nur die beiden Schreibweisen, mit denen ein
/// Bezeichner tatsächlich auf den Bildschirm kommt: `Text(x.referenz)` und
/// `${x.referenz}` in einer Zeichenkette. Die Referenz ist zugleich der
/// fachliche Schlüssel und steht deshalb völlig zu Recht in Suchen, Signalen,
/// HTTP-Parametern und Widget-Keys — von den gut hundert `.referenz` im
/// Frontend ist das die große Mehrheit. Ein Test, der die auch anspricht,
/// erzeugt Ausnahmen statt Klarheit.
void main() {
  // Die drei Stellen, an denen die volle Referenz fachlich trägt, plus die
  // Stellen, an denen sie gar nicht angezeigt, sondern als Schlüssel benutzt
  // wird. Jede Zeile nennt ihren Grund — eine neue kommt nur mit einem dazu.
  const erlaubt = <String, String>{
    'lib/features/zentralruf_reply/presentation/widgets/vorgang_zuordnung_auswahl.dart':
        'Zuordnung einer Zentralruf-Antwort: Hier entscheidet der Anwalt, ob '
        'die Antwort zu diesem Vorgang gehört — dafür braucht er das '
        'Kennzeichen, an dem der Zentralruf sie zurückschreibt.',
    'lib/features/mailbox/presentation/widgets/mailbox_vorgang_zuordnung.dart':
        'Derselbe Vergleich im Postfach: der Vorschlag „wahrscheinlich '
        'zugehörig" ist nur mit dem Kennzeichen nachprüfbar.',
    'lib/features/dashboard/presentation/widgets/dashboard_antwort_zeile.dart':
        'Zeigt die Referenz aus der Antwortmail, nicht die eines Vorgangs — '
        'sie ist dort der Rohtext, an dem die Zuordnung hängt, und ein '
        'Vorgang steht noch gar nicht fest.',
    'lib/features/mailbox/presentation/widgets/mailbox_reply_list.dart':
        'Derselbe Rohtext im Posteingang: was der Zentralruf unter „Ihr '
        'Zeichen" zurückgeschrieben hat, wird unverkürzt gezeigt.',
    'lib/features/word_automation/presentation/views/wizard_step_schadensaufstellung.dart':
        'Keine Anzeige, sondern ein ValueKey: die Referenz identifiziert das '
        'Formular, sie steht nirgends auf dem Bildschirm.',
    'lib/features/vorgaenge/presentation/widgets/zeichen_text.dart':
        'Der Baustein selbst — die Fundstelle steht in seinem Doc-Kommentar.',
  };

  // `Text(vorgang.referenz)`, auch über eine Kette wie `widget.vorgang`.
  final direkterText = RegExp(
    r'Text\(\s*[A-Za-z_][A-Za-z0-9_.!?]*\.referenz\b',
  );
  // `${vorgang.referenz}` in einer Zeichenkette. Der Umweg über
  // `ReferenzTeile.zeichenAus(...)` ist genau der erwünschte Weg und zählt
  // nicht — sonst stünde der Wächter gegen seine eigene Lösung.
  final interpolation = RegExp(r'\$\{(?![^}]*zeichenAus)[^}]*\.referenz\b');

  Iterable<File> anzeigedateien() => dartQuelldateien(
    'lib',
  ).where((f) => relPfad(f).contains('/presentation/'));

  test('die Oberfläche zeigt das Zeichen, nicht die volle Referenz', () {
    final verstoesse = <String>[];
    for (final datei in anzeigedateien()) {
      final pfad = relPfad(datei);
      if (erlaubt.containsKey(pfad)) continue;
      final inhalt = datei.readAsStringSync();
      if (direkterText.hasMatch(inhalt) || interpolation.hasMatch(inhalt)) {
        verstoesse.add(pfad);
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Dateien zeigen die volle Referenz statt des Zeichens. '
          'Richtig ist ZeichenText(vorgang), vorgang.zeichen oder '
          'ReferenzTeile.zeichenAus(referenz). Trägt die volle Referenz an '
          'der Stelle fachlich (Zentralruf-Formular, Zuordnung einer '
          'Antwort, Nebenzeile am Vorgang), gehört die Datei mit Begründung '
          'in die Liste `erlaubt` in diesem Test — nicht der Test gelockert.'
          '\nVerletzende Dateien:\n  ${verstoesse.join('\n  ')}',
    );
  });

  // Ohne diesen zweiten Test verrottet die Ausnahmeliste still: Wird eine der
  // Dateien umbenannt oder umgebaut, bleibt ihr Eintrag als Freibrief für
  // einen Pfad stehen, den es nicht mehr gibt.
  test(
    'die Ausnahmeliste zeigt auf vorhandene Dateien, die sie noch braucht',
    () {
      for (final eintrag in erlaubt.entries) {
        final datei = File(eintrag.key);
        expect(
          datei.existsSync(),
          isTrue,
          reason:
              'Die Ausnahme „${eintrag.key}" zeigt ins Leere. Datei verschoben '
              'oder gelöscht? Dann gehört der Eintrag mit.',
        );
        final inhalt = datei.readAsStringSync();
        expect(
          direkterText.hasMatch(inhalt) || interpolation.hasMatch(inhalt),
          isTrue,
          reason:
              'Die Ausnahme „${eintrag.key}" wird nicht mehr gebraucht — die '
              'Datei zeigt die volle Referenz gar nicht mehr an. Eintrag '
              'streichen, sonst deckt er künftige Rückfälle mit ab.',
        );
      }
    },
  );
}
