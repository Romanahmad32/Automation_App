import 'dart:io';

/// Findet den synchronisierten Ordner des angemeldeten Benutzers — den
/// wahrscheinlichsten Ablageort für den Register-Spiegel (§6.2).
///
/// Wichtig ist, was hier **nicht** passiert: Die App spricht mit keiner Cloud,
/// meldet sich nirgends an und kennt kein Konto. Sie liest lediglich die
/// Umgebungsvariablen, die der OneDrive-Client selbst setzt, und schlägt den
/// gefundenen Pfad vor. Gespeichert wird ein ganz gewöhnlicher Ordnerpfad; ob
/// dahinter OneDrive, ein Netzlaufwerk oder eine lokale Platte steht, ist der
/// App gleichgültig — der Synchronisierungsdienst erledigt den Rest.
///
/// Der Vorschlag ist eine Bequemlichkeit, kein Zwang: Wer woanders ablegen
/// will, wählt einen anderen Ordner.
class SynchronisierterOrdner {
  /// Die Variablen in der Reihenfolge, in der sie zutreffen. Das
  /// Geschäftskonto zuerst: Eine Kanzlei, die beides eingerichtet hat, meint
  /// mit „meinem OneDrive" das der Kanzlei.
  static const List<String> umgebungsvariablen = [
    'OneDriveCommercial',
    'OneDriveConsumer',
    'OneDrive',
  ];

  /// Unterordner, der unter dem gefundenen Pfad vorgeschlagen wird, damit der
  /// Spiegel nicht in der Wurzel der Synchronisierung landet.
  static const String unterordner = 'Kanzlei-Register';

  /// Der Vorschlag für den Ablageordner, oder null, wenn kein
  /// synchronisierter Ordner erkennbar ist. Der Ordner wird **nicht** angelegt
  /// — das tut erst das Backend beim ersten Schreiben.
  ///
  /// Bewusst asynchron. Die Umgebungsvariable steht sofort zur Verfügung, der
  /// Ordner dahinter nicht immer: Zeigt sie auf einen OneDrive-Bereich, der
  /// gerade getrennt ist oder auf „Dateien bei Bedarf" steht, braucht schon das
  /// blosse Nachsehen spürbar Zeit. Auf dem Zeichen-Thread hiesse das ein
  /// eingefrorenes Einstellungsformular.
  ///
  /// [umgebung] und [existiert] sind da, damit der Test denselben Weg fährt,
  /// der auch ausgeliefert wird. Vorher hing die Existenzprüfung daran, dass
  /// *keine* Umgebung übergeben wurde — die Tests liefen also durch einen
  /// Zweig, den es im Betrieb nie gibt, und der Betriebszweig war ungeprüft.
  static Future<String?> suche({
    Map<String, String>? umgebung,
    Future<bool> Function(String pfad)? existiert,
  }) async {
    final werte = umgebung ?? Platform.environment;
    final pruefe = existiert ?? (pfad) => Directory(pfad).exists();

    for (final name in umgebungsvariablen) {
      final pfad = (werte[name] ?? '').trim();
      if (pfad.isEmpty) continue;
      if (!await pruefe(pfad)) continue;
      return '$pfad${Platform.pathSeparator}$unterordner';
    }
    return null;
  }
}
