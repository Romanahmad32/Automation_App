import 'package:flutter/widgets.dart';

/// Wohin ein angeklickter Platzhalter geht — in den **Betreff** oder in die
/// **Nachricht** (§4.7).
///
/// **Der Mangel, den das behebt:** Der Vorlageneditor merkte sich das zuletzt
/// fokussierte Feld in einem stillen `bool`. Nichts auf dem Schirm sagte, wohin
/// der nächste Klick einfügt — und wer gerade nirgends stand, schrieb in den
/// Text, obwohl er den Betreff meinte. Jetzt trägt genau ein Objekt diese
/// Frage, es meldet jede Änderung ([ChangeNotifier]), und die zwei Stellen, die
/// es anzeigen (`BetreffTextFelder`, `PlatzhalterAuswahl`), zeigen deshalb
/// dasselbe.
///
/// Es hält **beide** Felder zusammen: die Controller kommen von aussen (der
/// Versanddialog füllt sie aus dem Cubit, der Editor aus der Vorlage), die
/// Fokusknoten gehören ihm. Ein Klick auf einen Platzhalter-Chip nimmt dem
/// Textfeld den Fokus, die Schreibmarke im Controller bleibt aber stehen —
/// deshalb ist der Fokusknoten die einzige verlässliche Auskunft darüber,
/// welches Feld gemeint war.
class PlatzhalterEinfuegeZiel extends ChangeNotifier {
  /// Der Betreff; die Vorgabe ist **nicht** er, siehe [zielIstBetreff].
  final TextEditingController betreff;

  final TextEditingController text;

  /// Wird nach dem Einfügen mit dem neuen Betreff gerufen. Nötig, weil ein
  /// programmatisch gesetzter `controller.value` **kein** `onChanged` auslöst:
  /// Ohne diesen Weg landete der eingefügte Platzhalter im Feld und nie im
  /// Entwurf. Null heisst: Das Feld führt sich selbst (Vorlageneditor).
  final ValueChanged<String>? onBetreffGeaendert;

  final ValueChanged<String>? onTextGeaendert;

  final FocusNode betreffFokus = FocusNode();
  final FocusNode textFokus = FocusNode();

  /// Wohin der nächste Platzhalter geht. Vorgabe ist der **Nachrichtentext** —
  /// dort stehen die meisten, und ein Klick ohne vorherigen Fokus soll nicht
  /// ins Leere gehen.
  bool _zielIstBetreff = false;

  PlatzhalterEinfuegeZiel({
    required this.betreff,
    required this.text,
    this.onBetreffGeaendert,
    this.onTextGeaendert,
  }) {
    betreffFokus.addListener(_beiBetreff);
    textFokus.addListener(_beiText);
  }

  bool get zielIstBetreff => _zielIstBetreff;

  /// Der Name des Ziels im Klartext — er steht an der Platzhalterhilfe und
  /// hinter der Beschriftung des getroffenen Feldes.
  String get zielName => _zielIstBetreff ? betreffName : textName;

  static const String betreffName = 'Betreff';
  static const String textName = 'Nachricht';

  /// Der Zusatz hinter der Feldbeschriftung, der das Ziel sichtbar macht.
  /// Öffentlich, weil ein Test darauf zeigt: Genau diese Auskunft fehlte.
  static const String marke = 'Ziel für Platzhalter';

  void _beiBetreff() {
    if (betreffFokus.hasFocus) waehleZiel(betreffIstZiel: true);
  }

  void _beiText() {
    if (textFokus.hasFocus) waehleZiel(betreffIstZiel: false);
  }

  /// Setzt das Ziel ausdrücklich. Der Fokus tut das von selbst; von Hand
  /// gebraucht wird es nur, wenn ein Feld gar nicht anfassbar ist.
  void waehleZiel({required bool betreffIstZiel}) {
    if (_zielIstBetreff == betreffIstZiel) return;
    _zielIstBetreff = betreffIstZiel;
    notifyListeners();
  }

  /// Setzt [platzhalter] an der Schreibmarke des Ziels ein und gibt den Fokus
  /// zurück — wer einen Namen einfügt, schreibt danach weiter.
  void fuegeEin(String platzhalter) {
    final ziel = _zielIstBetreff ? betreff : text;
    final auswahl = ziel.selection;
    final vorhanden = ziel.text;
    // Ohne gültige Schreibmarke (das Feld war noch nie fokussiert) hängt der
    // Platzhalter hinten an, statt an Position 0 vor den Text zu rutschen.
    final von = auswahl.isValid ? auswahl.start : vorhanden.length;
    final bis = auswahl.isValid ? auswahl.end : vorhanden.length;

    final neu = vorhanden.replaceRange(von, bis, platzhalter);
    ziel.value = TextEditingValue(
      text: neu,
      selection: TextSelection.collapsed(offset: von + platzhalter.length),
    );
    (_zielIstBetreff ? betreffFokus : textFokus).requestFocus();
    (_zielIstBetreff ? onBetreffGeaendert : onTextGeaendert)?.call(neu);
  }

  @override
  void dispose() {
    betreffFokus.dispose();
    textFokus.dispose();
    super.dispose();
  }
}
