import 'dart:io';

/// Verzeichnisse, die beim Aufbau des [Pfadverzeichnis] uebersprungen werden:
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
};

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
};

/// Vereinheitlicht Pfadtrenner zu `/`, damit Vergleiche und Meldungen auf
/// jedem Betriebssystem gleich aussehen (unter POSIX ein No-Op).
String normalisiert(String pfad) =>
    pfad.split(Platform.pathSeparator).join('/');

/// Der letzte Pfadbestandteil, unabhaengig vom Trennzeichen.
String dateiname(String pfad) => normalisiert(pfad).split('/').last;

/// Alle Dateien unterhalb der Repo-Wurzel, einmal eingelesen.
///
/// Der Doku-Test loest jeden Verweis gegen dieses Verzeichnis auf, statt eine
/// Liste moeglicher Wurzeln durchzuprobieren: die Doku nennt Dateien mal mit
/// Teilpfad (`Architecture/DateilaengeTests.cs`), mal blank
/// (`vorgang_cubit.dart`), und beide Schreibweisen sind gewollt.
class Pfadverzeichnis {
  Pfadverzeichnis._(this.pfade, this.dateinamen);

  /// Repo-relative Pfade, `/`-getrennt.
  final Set<String> pfade;

  /// Blosse Dateinamen ohne Ordneranteil.
  final Set<String> dateinamen;

  factory Pfadverzeichnis.ab(Directory wurzel) {
    final pfade = <String>{};
    final namen = <String>{};
    final praefix = '${normalisiert(wurzel.path)}/';
    final offen = <Directory>[wurzel];

    while (offen.isNotEmpty) {
      for (final eintrag in offen.removeLast().listSync(followLinks: false)) {
        final name = dateiname(eintrag.path);
        if (eintrag is Directory) {
          if (!nichtDurchsucht.contains(name)) offen.add(eintrag);
        } else if (eintrag is File) {
          final pfad = normalisiert(eintrag.path);
          pfade.add(
            pfad.startsWith(praefix) ? pfad.substring(praefix.length) : pfad,
          );
          namen.add(name);
        }
      }
    }
    return Pfadverzeichnis._(pfade, namen);
  }

  /// Ob [token] auf eine vorhandene Datei zeigt. Ein Token mit Ordneranteil
  /// muss als Pfadende vorkommen, ein blosser Dateiname irgendwo im Baum.
  bool kennt(String token) => token.contains('/')
      ? pfade.contains(token) || pfade.any((pfad) => pfad.endsWith('/$token'))
      : dateinamen.contains(token);
}

/// Alle Markdown-Dateien unterhalb von [pfad], stabil sortiert. Leere Liste,
/// wenn es den Ordner nicht gibt.
List<String> markdownUnter(String pfad) {
  final ordner = Directory(pfad);
  if (!ordner.existsSync()) return const [];
  return ordner
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
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
    if (keinVerweisZeichen.any(token.contains)) continue;
    // Blosse Endungen wie `.g.dart` benennen eine Dateiklasse, keine Datei.
    if (token.startsWith('.') && !token.contains('/')) continue;
    yield token;
  }
}
