import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter/material.dart';

/// Öffnet eine aus dem Posteingang geladene Datei — Anhang oder `.eml` — im
/// dafür eingerichteten Programm (§4.3).
///
/// Über [DateiOeffner], **denselben** Weg, den der Mail-Anhang vor dem
/// Absenden (`EmailAnhangChip`) und die Word-Vorlage im Vorlageneditor
/// (`VorlagenDateiOeffnen`) schon gehen — keine neue Abhängigkeit: Die
/// Mechanik (`rundll32`) liegt bereits in `core/dateien`, dieser Baustein
/// bindet sie nur an die Rückmeldung des Posteingangs.
class PosteingangDateiOeffnen {
  const PosteingangDateiOeffnen._();

  /// Öffnet [pfad]; ließ sich das nicht anstoßen (Datei weg, kein Programm
  /// dafür eingerichtet), sagt eine Rückmeldung es — mit dem Dateinamen
  /// [name], nicht dem Pfad: Der liest sich in einer flüchtigen Meldung
  /// niemand durch.
  ///
  /// [Rueckmeldung.von] **vor** dem `await`: Nach dem Öffnen kann die Seite
  /// weg sein (dasselbe Muster wie in `EmailAnhangChip`/`VorlagenDateiOeffnen`).
  static Future<void> oeffne(
    BuildContext context,
    String pfad, {
    required String name,
  }) async {
    final melder = Rueckmeldung.von(context);
    if (await DateiOeffner.oeffne(pfad)) return;

    melder.hinweis(
      '„$name" lässt sich nicht öffnen — liegt die Datei noch dort?',
      aktion: RueckmeldungsAktion(
        text: 'Im Ordner zeigen',
        beiDruck: () => DateiOeffner.zeigeImOrdner(pfad),
      ),
    );
  }
}
