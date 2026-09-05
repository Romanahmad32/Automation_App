import 'dart:io';

import 'package:automation_app/features/settings/domain/services/synchronisierter_wurzel_ordner.dart';

/// Findet den synchronisierten Ordner des angemeldeten Benutzers — den
/// wahrscheinlichsten Ablageort für den Register-Spiegel (§6.2) und für die
/// automatische Sicherung, über die der Stand an den zweiten Arbeitsplatz geht
/// (§7.2). Beide legen dieselbe Art Datei ab, nur zu verschiedenen Zwecken;
/// welcher Unterordner vorgeschlagen wird, sagt der Aufrufer.
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
  static const String registerUnterordner = 'Kanzlei-Register';

  /// Dasselbe für die Sicherungsablage (§7.2). Bewusst ein eigener Ordner: Der
  /// Register-Spiegel ist zum Lesen da und wird unterwegs geöffnet, die
  /// Sicherungen sind Archive, die niemand anfassen soll — in einem Ordner
  /// nebeneinander lüde das zum Aufräumen der falschen Dateien ein.
  static const String sicherungenUnterordner = 'Kanzlei-Sicherungen';

  /// Der Ordner, unter dem die App alles ablegt, was sie selbst verwaltet
  /// (#103) — Vorlagen, Register und Sicherungen entstehen darunter als
  /// Unterordner. Nur **ein** Name, weil aus vier Ordnerwahlen eine geworden
  /// ist; die drei Einzelfelder oben bleiben für den Sonderfall bestehen.
  ///
  /// Mit Leerzeichen und ohne Bindestrich, anders als die beiden Namen
  /// darüber: Dieser Ordner steht in der Wurzel der Synchronisierung und wird
  /// im Explorer gelesen, nicht getippt.
  static const String appDatenUnterordner = 'Kanzlei App Daten';

  /// Der erkannte Wurzelordner der Synchronisierung samt der Variablen, aus
  /// der er stammt — oder null, wenn keine der drei gesetzt ist bzw. keiner
  /// der Pfade auf der Platte liegt.
  ///
  /// Die Variable gehört zum Ergebnis, weil ein relativ abgelegter Ordner
  /// ohne sie mehrdeutig ist: Wer beide Konten hat, hat zwei Wurzeln (#103).
  ///
  /// [umgebung] und [existiert] sind da, damit der Test denselben Weg fährt,
  /// der auch ausgeliefert wird. Vorher hing die Existenzprüfung daran, dass
  /// *keine* Umgebung übergeben wurde — die Tests liefen also durch einen
  /// Zweig, den es im Betrieb nie gibt, und der Betriebszweig war ungeprüft.
  static Future<SynchronisierterWurzelOrdner?> sucheWurzel({
    Map<String, String>? umgebung,
    Future<bool> Function(String pfad)? existiert,
  }) async {
    final werte = umgebung ?? Platform.environment;
    final pruefe = existiert ?? (pfad) => Directory(pfad).exists();

    for (final name in umgebungsvariablen) {
      final pfad = (werte[name] ?? '').trim();
      if (pfad.isEmpty) continue;
      if (!await pruefe(pfad)) continue;
      return SynchronisierterWurzelOrdner(variable: name, pfad: pfad);
    }
    return null;
  }

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
  /// Setzt auf [sucheWurzel] auf und hängt nur noch den [unterordner] an:
  /// Zwei Fassungen derselben Suche liefen beim ersten Nachbessern
  /// auseinander, und die eine, die den Anker nicht kennt, wäre die
  /// gefährlichere.
  static Future<String?> suche({
    String unterordner = registerUnterordner,
    Map<String, String>? umgebung,
    Future<bool> Function(String pfad)? existiert,
  }) async {
    final wurzel = await sucheWurzel(umgebung: umgebung, existiert: existiert);
    if (wurzel == null) return null;
    return '${wurzel.pfad}${Platform.pathSeparator}$unterordner';
  }
}
