/// Vergleicht dreistellige Versionsnummern.
///
/// Ausdrücklich kein Zeichenkettenvergleich: `1.10.0` ist neuer als `1.9.0`,
/// obwohl `"1.1"` alphabetisch vor `"1.9"` steht. Führendes `v` (so heißen die
/// Git-Tags) und ein Anhang hinter `+` (der Commit aus der
/// InformationalVersion) werden vorher abgeschnitten.
class VersionsVergleich {
  const VersionsVergleich._();

  /// Ob [kandidat] eine höhere Version ist als [bekannt].
  ///
  /// Ist eine der beiden nicht lesbar, lautet die Antwort `false`. Ein
  /// Update-Hinweis, der auf einer Fehldeutung beruht, wäre schlimmer als
  /// keiner: der Anwalt lädt dann eine Datei herunter, die er schon hat.
  static bool istNeuer(String kandidat, String bekannt) {
    final links = teile(kandidat);
    final rechts = teile(bekannt);
    if (links == null || rechts == null) return false;

    for (var stelle = 0; stelle < links.length; stelle++) {
      if (links[stelle] != rechts[stelle]) return links[stelle] > rechts[stelle];
    }
    return false;
  }

  /// `v1.2.3+abc1234` → `[1, 2, 3]`; alles andere → `null`.
  static List<int>? teile(String version) {
    final kern = version
        .trim()
        .replaceFirst(RegExp(r'^v'), '')
        .split('+')
        .first;
    final stuecke = kern.split('.');
    if (stuecke.length != 3) return null;

    final zahlen = <int>[];
    for (final stueck in stuecke) {
      final zahl = int.tryParse(stueck);
      if (zahl == null || zahl < 0) return null;
      zahlen.add(zahl);
    }
    return zahlen;
  }
}
