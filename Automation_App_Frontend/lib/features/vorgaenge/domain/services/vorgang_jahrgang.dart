import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Der vierstellige Jahrgang eines [Vorgang] — die Überschrift, unter der er
/// im Register steht.
///
/// `Vorgang.jahr` steht zweistellig („26"), weil es aus dem Zeichen stammt; die
/// Zwischenüberschriften des Registers sind vierstellig. Ohne das Feld
/// entscheidet das Abschluss-, sonst das Anfragedatum.
///
/// Seit die Registeransicht ihre Zeilen aus dem Backend bezieht (Issue #109),
/// braucht **nur noch die Startseiten-Karte** diese Rechnung: Sie baut ihre
/// Zeilen aus dem bereits geladenen Vorgangsbestand
/// ([RegisterZeile.ausVorgang]) statt aus einem zweiten Abruf. Das Gegenstück
/// ist `RegisterZeilenBau.Jahrgang` im Backend; weichen beide ab, sortiert die
/// Startseite einen Vorgang unter ein anderes Jahr als die Registerseite.
abstract final class VorgangJahrgang {
  /// Nur Ziffern, nichts sonst. `int.tryParse` stand hier vorher und nahm auch
  /// ein Vorzeichen an: Aus dem Jahr „-1" wurde der Jahrgang „20-1", während
  /// das Backend auf das Datum zurückfiel. Darts `\d` ist ASCII-only und passt
  /// damit genau zu `char.IsAsciiDigit` drüben.
  static final RegExp _nurZiffern = RegExp(r'^\d+$');

  static String fuer(Vorgang vorgang) {
    final jahr = (vorgang.jahr ?? '').trim();
    if (jahr.length == 4 && _nurZiffern.hasMatch(jahr)) return jahr;
    if (jahr.length == 2 && _nurZiffern.hasMatch(jahr)) return '20$jahr';
    return '${(vorgang.abgeschlossenAm ?? vorgang.angefragtAm).year}';
  }
}
