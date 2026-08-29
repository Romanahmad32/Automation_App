import 'dart:io';

/// Datei-Endungen generierter Quellen, die von den Architektur- und
/// Längen-Tests ausgenommen sind (build_runner, freezed, json, auto_route, …).
const List<String> generierteEndungen = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.config.dart',
  '.mocks.dart',
];

bool istGeneriert(String pfad) =>
    generierteEndungen.any((endung) => pfad.endsWith(endung));

/// Normalisiert Windows-Backslashes zu Forward-Slashes, damit Pfadvergleiche
/// und Reports plattformunabhängig stabil sind.
String relPfad(File datei) => datei.path.replaceAll('\\', '/');

/// Zeilen einer Quelldatei ohne Leerzeilen und ohne reine Kommentarzeilen —
/// das Maß, an dem die Längenregel hängt (siehe `file_length_test.dart`).
///
/// Gezählt wird, was nach dem Trimmen übrig bleibt und nicht mit `//`, `/*`
/// oder `*` beginnt. Das erfasst Zeilen- und Doc-Kommentare sowie formatierte
/// Blockkommentare.
///
/// Es ist eine Näherung, und sie irrt in **beide** Richtungen. Zu viel: eine
/// Fließtextzeile innerhalb eines Blockkommentars, die nicht mit `*` eingerückt
/// ist. Zu wenig: jede Zeile innerhalb eines Zeichenkettenliterals, die mit
/// einem der drei Präfixe beginnt — eine URL in einem `'''…'''`, eine
/// Aufzählung mit `*`, eingebetteter Code mit eigenen Kommentaren. Eine Datei
/// kann die Grenze also auch reißen, ohne dass dieser Test es merkt.
///
/// Das ist bewusst in Kauf genommen: Sauber unterscheiden hieße tokenisieren,
/// und die Regel ist eine Faustzahl für die Lesbarkeit, kein Beweis. Wer sie
/// schärfer braucht, fängt bei den Zeichenkettenliteralen an — nicht bei den
/// Kommentarpräfixen.
///
/// Dieselbe Zählweise steht in `Quelldatei.IstAnweisungszeile` im Backend. Wer
/// eine der beiden ändert, ändert die andere mit — sonst gilt für dieselbe
/// Regel auf beiden Seiten eine andere Zahl.
int anweisungszeilen(File datei) =>
    datei.readAsLinesSync().where(istAnweisungszeile).length;

bool istAnweisungszeile(String zeile) {
  final inhalt = zeile.trim();
  if (inhalt.isEmpty) return false;
  return !inhalt.startsWith('//') &&
      !inhalt.startsWith('/*') &&
      !inhalt.startsWith('*');
}

/// Alle handgeschriebenen Dart-Dateien unter [verzeichnis] (rekursiv),
/// ohne generierte Dateien. Stabil sortiert für reproduzierbare Reports.
///
/// Erwartet das Paket-Stammverzeichnis als Arbeitsverzeichnis (so läuft
/// `flutter test`); andernfalls wird mit einem klaren Hinweis abgebrochen.
List<File> dartQuelldateien(String verzeichnis) {
  final dir = Directory(verzeichnis);
  if (!dir.existsSync()) {
    throw StateError(
      'Verzeichnis "$verzeichnis" nicht gefunden. Die Architektur-Tests '
      'müssen aus dem Paket-Stammverzeichnis (Automation_App_Frontend) laufen.',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !istGeneriert(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}
