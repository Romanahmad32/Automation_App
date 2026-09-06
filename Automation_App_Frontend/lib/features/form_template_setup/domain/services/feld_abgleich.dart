import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';

/// Was ein **Dateiwechsel** an der Vorlage kaputtgemacht hat (#104, §5.3):
/// Felder, deren Platzhalter vorher in einer Word-Datei ankam und nachher
/// nirgends mehr.
///
/// Der Fall dahinter: Der Anwalt tauscht die verknüpfte `.docx` gegen eine
/// überarbeitete aus. Bisher blieben die Felder der alten Fassung stumm
/// stehen; sichtbar wurde das erst als Warnung „in keiner Datei" an jeder
/// einzelnen Zeile — oder gar nicht, weil niemand achtzehn Zeilen durchsieht.
/// Hier wird derselbe Befund **einmal** gesammelt und als Frage gestellt
/// (`zeigeAbgleichDialog`).
///
/// Gefragt, nicht gelöscht (§1.3): Diese Klasse entscheidet nichts, sie
/// benennt nur die Kandidaten.
class FeldAbgleich {
  const FeldAbgleich._();

  /// Die Feldnamen, die den Wechsel nicht überlebt haben — in der Reihenfolge
  /// der Felder, jeder Name einmal, in der Schreibweise des Feldes.
  ///
  /// [vorher] und [nachher] sind zwei Rechnungen desselben Standes
  /// ([VorlagenStand]), einmal vor und einmal nach dem Einlesen der neuen
  /// Datei; [feldnamen] sind die **aufgelösten** Feldnamen (nicht die
  /// Control-Schlüssel `field_0`, siehe FEATURE.md).
  ///
  /// **Bei unbekannter Platzhalterliste wird nichts vorgeschlagen** — weder
  /// vorher noch nachher. Ein Ladezustand oder ein Lesefehler ist kein Befund,
  /// und der Vorschlag hier ist das Löschen von Feldern: Im Zweifel nichts
  /// anmahnen statt falsch anmahnen (dieselbe Haltung wie
  /// `VorlagenStand.felderOhneVorkommen`). Ohne Datei **vorher** ebenfalls
  /// nichts: Was nie ein Vorkommen hatte, ist auch keins losgeworden.
  static List<String> verschwundeneFelder({
    required Iterable<String?> feldnamen,
    required VorlagenStand vorher,
    required VorlagenStand nachher,
  }) {
    if (nachher.platzhalterUnbekannt) return const [];
    if (vorher.platzhalterUnbekannt || !vorher.hatDatei) return const [];

    // Verglichen wird ohne Groß-/Kleinschreibung, wie die Ersetzung im
    // Backend und wie `FeldVorkommen`.
    final vorherOhneVorkommen = {
      for (final name in vorher.felderOhneVorkommen) name.toLowerCase(),
    };
    final nachherOhneVorkommen = {
      for (final name in nachher.felderOhneVorkommen) name.toLowerCase(),
    };

    final gesehen = <String>{};
    final ergebnis = <String>[];
    for (final name in feldnamen) {
      final sauber = name?.trim();
      if (sauber == null || sauber.isEmpty) continue;
      final klein = sauber.toLowerCase();
      // Vorher schon ohne Vorkommen: Das ist ein alter Befund, kein Verlust
      // durch diesen Wechsel — die Feldzeile zeigt ihn ohnehin.
      if (vorherOhneVorkommen.contains(klein)) continue;
      if (!nachherOhneVorkommen.contains(klein)) continue;
      if (!gesehen.add(klein)) continue;
      ergebnis.add(sauber);
    }
    return ergebnis;
  }
}
