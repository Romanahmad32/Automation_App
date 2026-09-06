import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagenname_vorschlag.dart';
import 'package:flutter/material.dart';

/// **Der eine** Weg, aus dem Vorlageneditor die verknüpfte `.docx` in Word zu
/// öffnen — aus der Auswahlseite (`VorlagenDateiKachel`) und aus der
/// Dateikarte des Editors (`TemplateFileSlotCard`).
///
/// Der Grund für den Knopf: Wer beim Einrichten merkt, dass ein Platzhalter
/// falsch geschrieben ist, muss ihn in Word reparieren. Bisher hieß das, die
/// Datei im Explorer zu suchen — mit einem Pfad, den nur der Tooltip der Karte
/// zeigte.
///
/// Eigene Klasse statt zweier gleicher Blöcke in den beiden Karten: Der
/// Fehlerfall gehört zur Handlung, nicht zur Karte, und zwei Fassungen
/// derselben Meldung liefen bei der nächsten Änderung auseinander. Die
/// Mechanik selbst (`rundll32`) liegt in [DateiOeffner] und ist dort auch die
/// Test-Naht.
class VorlagenDateiOeffnen {
  const VorlagenDateiOeffnen._();

  /// Öffnet [pfad] im dafür eingerichteten Programm; ließ sich das nicht
  /// anstoßen, sagt eine Rückmeldung es.
  ///
  /// Gemeldet wird der **Dateiname**, nicht der Pfad: Der Anwalt erkennt an
  /// `HGn.docx`, welche der beiden Dateien gemeint ist, und ein
  /// Verzeichnispfad in einer flüchtigen Meldung liest sich niemand durch.
  ///
  /// [Rueckmeldung.von] **vor** dem `await`: Nach dem Öffnen kann die Seite
  /// weg sein, und ein Zugriff auf den Kontext liefe dann ins Leere (dasselbe
  /// Muster wie in `EmailAnhangChip`).
  static Future<void> inWord(BuildContext context, String pfad) async {
    final melder = Rueckmeldung.von(context);
    if (await DateiOeffner.oeffne(pfad)) return;

    melder.hinweis(
      'Die Datei wurde nicht gefunden: '
      '${VorlagennameVorschlag.dateiname(pfad)}',
      aktion: RueckmeldungsAktion(
        text: 'Im Ordner zeigen',
        beiDruck: () => DateiOeffner.zeigeImOrdner(pfad),
      ),
    );
  }
}
