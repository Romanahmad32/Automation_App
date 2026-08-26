import 'dart:io';

/// Wie ein Anhang in der Oberfläche erscheint: Dateiname statt vollem Pfad,
/// Größe in einer Einheit, die ein Mensch liest.
///
/// Bewusst ohne `package:path` — der Bestand ermittelt Dateinamen mit demselben
/// Einzeiler (`akten_datasource.dart`), und eine Abhängigkeit für einen
/// `split` einzuführen, lohnt nicht.
class AnhangDarstellung {
  const AnhangDarstellung._();

  /// Der Dateiname ohne Verzeichnis. In einer Chip-Zeile mit vollem Pfad
  /// erkennt niemand, ob da das Schreiben oder das Gutachten hängt.
  static String name(String pfad) => pfad.split(RegExp(r'[\\/]')).last;

  /// Größe als Klartext, leer wenn die Datei inzwischen fehlt — der Versand
  /// meldet das ohnehin, und zwar bevor etwas hinausgeht.
  static String groesse(String pfad) {
    try {
      final bytes = File(pfad).lengthSync();
      if (bytes < 1024) return '$bytes Bytes';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } on FileSystemException {
      return '';
    }
  }
}
