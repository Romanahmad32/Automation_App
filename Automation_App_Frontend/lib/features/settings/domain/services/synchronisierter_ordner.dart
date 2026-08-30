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
  static String? vorschlag([Map<String, String>? umgebung]) {
    final werte = umgebung ?? Platform.environment;
    for (final name in umgebungsvariablen) {
      final pfad = (werte[name] ?? '').trim();
      if (pfad.isEmpty) continue;
      if (umgebung == null && !Directory(pfad).existsSync()) continue;
      return '$pfad${Platform.pathSeparator}$unterordner';
    }
    return null;
  }
}
