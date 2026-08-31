import 'dart:io';

/// Holt eine außerhalb des Vorlagenordners gewählte Word-Datei in den Ordner
/// (#33). Eine Vorlage außerhalb bleibt zwar nutzbar (absolut verknüpft), wird
/// aber nicht mitgesichert und fehlt damit auf einem zweiten Rechner — deshalb
/// bietet die Auswahl das Kopieren an.
class VorlagenHineinholen {
  /// Liegt [pfad] im [ordner]? Der Trenner am Ende verhindert, dass
  /// `C:\VorlagenAlt` als Inhalt von `C:\Vorlagen` durchgeht; Groß-/
  /// Kleinschreibung zählt nicht (Windows-Dateisystem).
  static bool liegtImOrdner(String ordner, String pfad) {
    final wurzel = ordner.endsWith(Platform.pathSeparator)
        ? ordner
        : '$ordner${Platform.pathSeparator}';
    return pfad.toLowerCase().startsWith(wurzel.toLowerCase());
  }

  /// Kopiert [quelle] in den [ordner] und liefert den neuen Pfad — oder null,
  /// wenn dort schon eine gleichnamige Datei liegt: Überschreiben könnte eine
  /// andere Vorlage zerstören, das entscheidet der Anwalt im Explorer.
  static Future<String?> kopiere({
    required String ordner,
    required String quelle,
  }) async {
    final dateiname = quelle.split(Platform.pathSeparator).last;
    final ziel = '$ordner${Platform.pathSeparator}$dateiname';
    if (File(ziel).existsSync()) {
      return null;
    }
    await File(quelle).copy(ziel);
    return ziel;
  }
}
