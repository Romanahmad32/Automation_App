import 'dart:io';

/// Verzeichnisse, die beim Durchlaufen des Repos uebersprungen werden:
/// Build-Ausgaben, Werkzeugcaches und Fremdcode. Ohne diese Liste laeuft der
/// Doku-Test minutenlang durch `.git/` und `.dart_tool/`.
const Set<String> nichtDurchsucht = {
  '.git',
  '.dart_tool',
  '.idea',
  '.vs',
  'bin',
  'obj',
  'build',
  'node_modules',
  'packages',
  'ephemeral',
  'Generated',
  // Der gepackte Auslieferstand (`.gitignore`). Er enthaelt Zweitfassungen
  // versionierter Dateien — `appsettings.json` liegt dort ein zweites Mal.
  // Ohne diesen Eintrag entschiede eine Build-Ausgabe darueber, ob ein blosser
  // Dateiname im Repo eindeutig ist (siehe Pfadverzeichnis.kennt).
  'dist',
  // Ein Worktree ist eine zweite, vollstaendige Kopie des Repos — womoeglich
  // auf einem anderen Zweig. Seine Doku gegen den Dateibestand *dieses*
  // Arbeitsverzeichnisses zu pruefen, beantwortet keine Frage und schlaegt
  // frueher oder spaeter grundlos an.
  'worktrees',
};

/// Alle Dateien unterhalb von [wurzel], ohne die [nichtDurchsucht]-Ordner.
///
/// Bricht schon beim Absteigen ab, statt hinterher zu filtern:
/// `listSync(recursive: true)` liest `.git/`, `.dart_tool/` und einen
/// danebenliegenden Worktree erst vollstaendig ein, nur damit das Ergebnis
/// danach weggeworfen wird.
Iterable<File> dateienUnter(Directory wurzel) sync* {
  final offen = <Directory>[wurzel];
  while (offen.isNotEmpty) {
    for (final eintrag in offen.removeLast().listSync(followLinks: false)) {
      if (eintrag is Directory) {
        if (!nichtDurchsucht.contains(dateiname(eintrag.path))) {
          offen.add(eintrag);
        }
      } else if (eintrag is File) {
        yield eintrag;
      }
    }
  }
}

/// Endungen, an denen ein Backtick-Token als Verweis auf eine Datei im Repo
/// erkannt wird.
///
/// Bewusst ohne `.docx`, `.db` und `.bin`: das sind Anwender- und
/// Laufzeitdateien (`%APPDATA%`, `Beispiele/`), die im frischen Klon fehlen
/// duerfen und deshalb nichts ueber die Richtigkeit der Doku aussagen.
final RegExp verweisEndung = RegExp(r'\.(dart|cs|md|json|ps1|ya?ml|csproj)$');

/// Zeichen, an denen ein Token *kein* Dateiverweis ist: Platzhalter
/// (`<feature>`), Glob-Muster (`Vorlagen/*.docx`), ganze Befehlszeilen
/// (Leerzeichen) und Windows-Laufzeitpfade (`%APPDATA%`).
const Set<String> keinVerweisZeichen = {' ', '*', '<', '>', '%'};

/// Verweise, die absichtlich ins Leere zeigen duerfen — jeder mit Grund.
///
/// Diese Liste ist die einzige zugelassene Form der Ausnahme. Wer einen toten
/// Verweis hier eintraegt, ohne den Grund benennen zu koennen, hat statt der
/// Doku den Test repariert.
const Map<String, String> verweisAusnahmen = {
  '.claude/settings.local.json': 'maschinenlokal, steht in .gitignore',
  'kanzlei_settings.json':
      'abgeschaffter JSON-Speicher; wird in CLAUDE.md genannt, um zu sagen, '
      'dass es ihn nicht mehr gibt',
  'mandanten.json': 'abgeschaffter JSON-Speicher, wie kanzlei_settings.json',
  'mailbox_config.json':
      'Laufzeitdatei unter %APPDATA%, entsteht erst im Betrieb (docs/RELEASE.md '
      'listet sie als Pfad, den ein Update unberuehrt laesst)',
  'letzte-sicherung.json':
      'Laufzeitdatei unter %APPDATA%, wie mailbox_config.json: Ergebnis des '
      'letzten automatischen Sicherungslaufs (#39), entsteht erst im Betrieb',
};

/// Namen, die eine **Gattung** benennen statt einer bestimmten Datei — wie
/// `.g.dart` eine Dateiklasse benennt. Jeder von ihnen kommt im Repo je
/// Teilbaum, Feature oder Programm genau einmal vor; welcher gemeint ist,
/// sagt der Satz drumherum („die `FEATURE.md` des Features", „aus der
/// Wurzel-`CLAUDE.md`"). Einen Pfad hineinzuschreiben machte solche Saetze
/// falsch, nicht genauer.
///
/// Dass es sie gibt, bewacht je ein eigener Test: die drei `CLAUDE.md` das
/// Wortbudget, die Steckbriefe der Steckbrief-Test, das Paar aus Steckbrief
/// und `FALLSTRICKE.md` der Nennt-einander-Test. Nur `Program.cs` steht ohne
/// Wache da — ohne ihn gaebe es kein Programm.
const Map<String, String> gattungsnamen = {
  'CLAUDE.md': 'eine je Teilbaum, dazu die Wurzel-Datei',
  'FEATURE.md': 'ein Steckbrief je Feature',
  'FALLSTRICKE.md': 'hoechstens einer je Feature',
  'Program.cs':
      'Pflichtname des .NET-Einstiegspunkts, einer je Programm '
      '(Dienst und die zwei Werkzeuge unter tools/)',
};

/// Vereinheitlicht Pfadtrenner zu `/`, damit Vergleiche und Meldungen auf
/// jedem Betriebssystem gleich aussehen (unter POSIX ein No-Op).
String normalisiert(String pfad) =>
    pfad.split(Platform.pathSeparator).join('/');

/// Der letzte Pfadbestandteil, unabhaengig vom Trennzeichen.
String dateiname(String pfad) => normalisiert(pfad).split('/').last;

/// Woerter einer Doku-Datei: alles, was durch Leerraum getrennt ist. Zaehlt
/// Aufzaehlungsstriche und Tabellenbalken mit — es geht um die
/// Groessenordnung, nicht um eine Zaehlung auf das Wort genau.
int woerter(File datei) => datei
    .readAsStringSync()
    .split(RegExp(r'\s+'))
    .where((wort) => wort.isNotEmpty)
    .length;

/// Der Ordneranteil eines `/`-getrennten Pfades, leer bei einer Datei ganz
/// oben.
String ordnerAnteil(String pfad) {
  final teile = pfad.split('/');
  return teile.length < 2 ? '' : teile.sublist(0, teile.length - 1).join('/');
}

/// Ein relativ angegebener Pfad, absolut und ohne `.`/`..`-Schritte.
String aufgeloest(String pfad) {
  final teile = <String>[];
  for (final teil in normalisiert(File(pfad).absolute.path).split('/')) {
    if (teil == '.' || teil.isEmpty) continue;
    if (teil == '..') {
      if (teile.isNotEmpty) teile.removeLast();
      continue;
    }
    teile.add(teil);
  }
  return teile.join('/');
}

/// Alle Dateien unterhalb der Repo-Wurzel, einmal eingelesen.
///
/// Der Doku-Test loest jeden Verweis gegen dieses Verzeichnis auf, statt eine
/// Liste moeglicher Wurzeln durchzuprobieren: die Doku nennt Dateien mal mit
/// Teilpfad (`Architecture/DateilaengeTests.cs`), mal blank
/// (`vorgang_cubit.dart`), und beide Schreibweisen sind gewollt.
class Pfadverzeichnis {
  Pfadverzeichnis._(this.wurzel, this.pfade, this.haeufigkeit);

  /// Absoluter, aufgeloester Pfad der Repo-Wurzel, `/`-getrennt.
  final String wurzel;

  /// Repo-relative Pfade, `/`-getrennt.
  final Set<String> pfade;

  /// Wie oft ein blosser Dateiname im Repo vorkommt.
  final Map<String, int> haeufigkeit;

  factory Pfadverzeichnis.ab(Directory wurzel) {
    final pfade = <String>{};
    final haeufigkeit = <String, int>{};
    // Der Walker liefert die Pfade so, wie [wurzel] angegeben wurde (also
    // relativ, `../…`); abgeschnitten wird deshalb dieser Anfang, nicht der
    // aufgeloeste. Der aufgeloeste dient nur dazu, einen anderswo relativ
    // angegebenen Pfad auf dieselbe Repo-Sicht umzurechnen (repoRelativ).
    final absolut = aufgeloest(wurzel.path);
    final praefix = '${normalisiert(wurzel.path)}/';

    for (final datei in dateienUnter(wurzel)) {
      final pfad = normalisiert(datei.path);
      pfade.add(
        pfad.startsWith(praefix) ? pfad.substring(praefix.length) : pfad,
      );
      final name = dateiname(datei.path);
      haeufigkeit[name] = (haeufigkeit[name] ?? 0) + 1;
    }
    return Pfadverzeichnis._(absolut, pfade, haeufigkeit);
  }

  /// Der repo-relative Pfad zu [pfad], der wie im Test relativ zum
  /// Arbeitsverzeichnis (dem Paket-Stammverzeichnis) angegeben ist.
  String repoRelativ(String pfad) {
    final absolut = aufgeloest(pfad);
    return absolut.startsWith('$wurzel/')
        ? absolut.substring(wurzel.length + 1)
        : absolut;
  }

  /// Ob [token] auf eine vorhandene Datei zeigt, genannt in [genanntIn].
  ///
  /// Ein Token mit Ordneranteil muss als Pfadende vorkommen. Ein **blosser
  /// Dateiname** dagegen wird unterhalb des Dokuments aufgeloest, das ihn
  /// nennt — ausser der Name kommt im Repo nur ein einziges Mal vor, dann ist
  /// er ohnehin eindeutig.
  ///
  /// Vorher galt jeder blosse Name als bekannt, sobald *irgendwo* im Baum eine
  /// Datei so hiess. Das ist bei den Doku-Dateinamen, die es je Feature einmal
  /// gibt, ein Freibrief: Solange *ein* Feature eine `FALLSTRICKE.md` hat,
  /// darf jeder andere Steckbrief auf eine geloeschte Nachbardatei zeigen,
  /// ohne dass etwas rot wird — ein toter Verweis genau der Art, gegen die es
  /// diesen Test gibt.
  bool kennt(String token, {required String genanntIn}) {
    if (token.contains('/')) {
      return pfade.contains(token) ||
          pfade.any((pfad) => pfad.endsWith('/$token'));
    }
    if (haeufigkeit[token] == 1) return true;

    final ordner = ordnerAnteil(repoRelativ(genanntIn));
    final praefix = ordner.isEmpty ? '' : '$ordner/';
    return pfade.any(
      (pfad) =>
          pfad == '$praefix$token' ||
          (pfad.startsWith(praefix) && pfad.endsWith('/$token')),
    );
  }
}

/// Alle Markdown-Dateien unterhalb von [pfad], stabil sortiert. Leere Liste,
/// wenn es den Ordner nicht gibt.
List<String> markdownUnter(String pfad) {
  final ordner = Directory(pfad);
  if (!ordner.existsSync()) return const [];
  // Ueber denselben Walker wie das Pfadverzeichnis, also mit derselben
  // Ausnahmeliste. Ohne sie liest der Doku-Test bis in die Build-Ausgabe
  // hinein und prueft die mitgelieferte Fremddokumentation von Playwright —
  // Verweise, die niemand hier geschrieben hat und niemand hier berichtigen
  // kann.
  return dateienUnter(ordner)
      .map((datei) => normalisiert(datei.path))
      .where((datei) => datei.endsWith('.md'))
      .toList()
    ..sort();
}

/// Die Backtick-Token aus [markdown], die wie ein Dateiverweis aussehen.
Iterable<String> verweiseIn(String markdown) sync* {
  for (final treffer in RegExp(r'`([^`\n]+)`').allMatches(markdown)) {
    final token = treffer.group(1)!;
    if (!verweisEndung.hasMatch(token)) continue;
    if (verweisAusnahmen.containsKey(token)) continue;
    if (gattungsnamen.containsKey(token)) continue;
    if (keinVerweisZeichen.any(token.contains)) continue;
    // Blosse Endungen wie `.g.dart` benennen eine Dateiklasse, keine Datei.
    if (token.startsWith('.') && !token.contains('/')) continue;
    yield token;
  }
}
