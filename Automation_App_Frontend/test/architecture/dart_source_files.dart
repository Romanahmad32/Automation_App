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
