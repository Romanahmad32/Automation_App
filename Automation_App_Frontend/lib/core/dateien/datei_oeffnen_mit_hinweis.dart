import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:material_ui/material_ui.dart';

/// **Der eine** Weg, aus der Oberfläche eine Datei zu öffnen und dem Anwalt zu
/// sagen, wenn das nicht ging: der Mail-Anhang vor dem Absenden, die Word-Vorlage
/// im Vorlageneditor, der Anhang im Posteingang, „In Word öffnen“ im Prüfschritt
/// des Word-Assistenten.
///
/// Öffentliche API: [oeffne] — `DateiOeffnenMitHinweis.oeffne(context, pfad)`,
/// optional mit [name] für den Namen, unter dem der Anwalt die Datei kennt
/// (Standard: der Dateiname aus dem Pfad).
///
/// Warum der eine Weg: Vorher gab es drei fast gleiche Fassungen von „Datei
/// öffnen, sonst Hinweis mit ‚Im Ordner zeigen‘“ (Vorlageneditor, Posteingang,
/// Anhang-Chip) mit zwei verschiedenen Meldungstexten, und der Prüfschritt
/// startete Word von Hand über `cmd /c start`. Der Fehlerfall gehört zur
/// Handlung, nicht zum Widget, und mehrere Fassungen laufen bei der nächsten
/// Änderung auseinander. Die Mechanik (`rundll32`) und die Test-Naht liegen in
/// [DateiOeffner]; hier liegt, was der Anwalt erfährt.
///
/// Gemeldet wird der **Dateiname**, nicht der Pfad: Ein Verzeichnispfad liest
/// sich in einer flüchtigen Meldung niemand durch.
class DateiOeffnenMitHinweis {
  const DateiOeffnenMitHinweis._();

  /// Öffnet [pfad] im dafür eingerichteten Programm; ließ sich das nicht
  /// anstoßen (Datei weg, kein Programm dafür), sagt eine Rückmeldung es — mit
  /// der Aktion „Im Ordner zeigen“.
  ///
  /// [Rueckmeldung.von] **vor** dem `await`: Nach dem Öffnen kann die Seite weg
  /// sein, und ein Zugriff auf den Kontext liefe dann ins Leere.
  static Future<void> oeffne(
    BuildContext context,
    String pfad, {
    String? name,
  }) async {
    final melder = Rueckmeldung.von(context);
    if (await DateiOeffner.oeffne(pfad)) return;

    final gemeldet = name ?? pfad.split(RegExp(r'[\\/]')).last;
    melder.hinweis(
      '„$gemeldet“ lässt sich nicht öffnen — liegt die Datei noch dort?',
      aktion: RueckmeldungsAktion(
        text: 'Im Ordner zeigen',
        beiDruck: () => DateiOeffner.zeigeImOrdner(pfad),
      ),
    );
  }
}
