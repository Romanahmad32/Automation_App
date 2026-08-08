/// Version der laufenden Anwendung.
///
/// Die Quelle ist `GET /health` des lokalen Dienstes und nicht die eigene
/// pubspec: die Versionsnummer wird beim Paketbau aus dem Git-Tag in *beide*
/// Hälften geschrieben, und der Rauchtest prüft sie genau an diesem Endpunkt
/// nach. Was hier steht, ist also dieselbe Zahl, die die Auslieferung bestätigt
/// hat — und läuft ausnahmsweise ein fremder Dienst auf dem Port, fällt das
/// hier auf, statt still zu bleiben.
class AppVersion {
  const AppVersion(this.roh);

  /// Wie der Dienst sie meldet, z. B. `1.0.0+34888af…`. Der Anhang hinter dem
  /// Plus ist der Commit, aus dem gebaut wurde (SourceLink des SDK).
  final String roh;

  /// Was dem Anwender gezeigt wird: `1.0.0`. Der Commit-Anhang gehört ins
  /// Protokoll, nicht in die Seitenleiste.
  String get anzeige => roh.split('+').first.trim();

  /// Fällt der Dienst mit einer unbrauchbaren Antwort auf, soll die Oberfläche
  /// trotzdem etwas Ehrliches anzeigen können.
  static const String unbekannt = 'unbekannt';
}
