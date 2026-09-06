import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:flutter/material.dart';

/// Betreff und Nachrichtentext als **ein** Baustein — der Versanddialog und der
/// Vorlageneditor tragen dieselben zwei Felder (§4.7).
///
/// Vorher standen sie zweimal da, in zwei Dateien, mit zwei Beschriftungen und
/// zwei Vorstellungen davon, wohin ein Platzhalter eingefügt wird. Der Editor
/// merkte sich das Ziel still, der Versanddialog kannte gar keins.
///
/// **Das Ziel steht am Feld.** Welches der beiden ein Klick in der
/// Platzhalterhilfe trifft, sagt die Beschriftung selbst
/// ([PlatzhalterEinfuegeZiel.marke]) — die Auskunft, die vorher nirgends stand.
class BetreffTextFelder extends StatelessWidget {
  final PlatzhalterEinfuegeZiel ziel;

  /// Was am Betreff fehlt; null heisst: nichts. Steht als `errorText` am Feld.
  final String? betreffFehler;

  /// Erläuterung unter dem Nachrichtenfeld; null lässt sie weg.
  final String? textHilfe;

  final bool aktiv;

  /// Wie hoch das Nachrichtenfeld mindestens und höchstens wird. Neben der
  /// Vorschau ist weniger mehr — dort scrollt das Formular ohnehin.
  final int minZeilen;
  final int maxZeilen;

  const BetreffTextFelder({
    super.key,
    required this.ziel,
    this.betreffFehler,
    this.textHilfe,
    this.aktiv = true,
    this.minZeilen = 8,
    this.maxZeilen = 16,
  });

  /// Die Beschriftung eines Feldes, mit dem Zusatz, wenn es das Ziel ist.
  /// Öffentlich, weil ein Test darauf zeigt.
  static String beschriftung(String feld, {required bool istZiel}) =>
      istZiel ? '$feld · ${PlatzhalterEinfuegeZiel.marke}' : feld;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ziel,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          TextField(
            controller: ziel.betreff,
            focusNode: ziel.betreffFokus,
            enabled: aktiv,
            decoration: InputDecoration(
              labelText: beschriftung(
                PlatzhalterEinfuegeZiel.betreffName,
                istZiel: ziel.zielIstBetreff,
              ),
              border: const OutlineInputBorder(),
              errorText: betreffFehler,
              errorMaxLines: 3,
              isDense: true,
            ),
            onChanged: ziel.onBetreffGeaendert,
          ),
          TextField(
            controller: ziel.text,
            focusNode: ziel.textFokus,
            enabled: aktiv,
            minLines: minZeilen,
            maxLines: maxZeilen,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: beschriftung(
                PlatzhalterEinfuegeZiel.textName,
                istZiel: !ziel.zielIstBetreff,
              ),
              alignLabelWithHint: true,
              helperText: textHilfe,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onChanged: ziel.onTextGeaendert,
          ),
        ],
      ),
    );
  }
}
