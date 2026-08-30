import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';

/// Entscheidet, ob ein erkannter Platzhalter als Eingabefeld übernommen werden
/// darf — die eine Stelle für diese Regel: Der Einzelklick auf einen Chip und
/// ein künftiges „Alle übernehmen" (#35 Teil 3) fragen beide hier.
class PlatzhalterUebernahme {
  const PlatzhalterUebernahme._();

  /// Warum [placeholder] **nicht** übernommen wird — als Satz für die
  /// Snackbar. Null heißt: übernehmen.
  ///
  /// [vorhandeneNamen] sind die aktuell eingetragenen Feldnamen (die Werte der
  /// Formular-Controls, nicht `FieldData.label` — das hält auf der offenen
  /// Detailseite nur den Control-Schlüssel, siehe FEATURE.md).
  static String? ablehnungsgrund(
    String placeholder,
    Iterable<String?> vorhandeneNamen,
  ) {
    if (AppEigenePlatzhalter.istAppEigen(placeholder)) {
      return '"$placeholder" füllt die App beim Erzeugen selbst — '
          'kein Eingabefeld nötig.';
    }
    final schonDa = vorhandeneNamen.any(
      (name) => name?.trim().toLowerCase() == placeholder.toLowerCase(),
    );
    if (schonDa) {
      return 'Das Feld "$placeholder" existiert bereits.';
    }
    return null;
  }

  /// Was „Alle übernehmen" (#35 Teil 3) tatsächlich übernimmt: die
  /// [placeholders] in Dokumentreihenfolge, ohne app-eigene, ohne
  /// Namensgleiche zu [vorhandeneNamen] und ohne Doppelte untereinander
  /// (denselben Namen können beide Word-Dateien liefern).
  static List<String> uebernehmbare(
    List<String> placeholders,
    Iterable<String?> vorhandeneNamen,
  ) {
    final belegt = {
      for (final name in vorhandeneNamen)
        if (name != null) name.trim().toLowerCase(),
    };
    final ergebnis = <String>[];
    for (final placeholder in placeholders) {
      if (AppEigenePlatzhalter.istAppEigen(placeholder)) continue;
      final klein = placeholder.trim().toLowerCase();
      if (!belegt.add(klein)) continue;
      ergebnis.add(placeholder);
    }
    return ergebnis;
  }

  /// Ob [placeholder] bereits als Eingabefeld existiert — für die Chip-Optik
  /// („übernommen") und die Zählzeile.
  static bool istUebernommen(
    String placeholder,
    Iterable<String?> vorhandeneNamen,
  ) {
    final klein = placeholder.trim().toLowerCase();
    return vorhandeneNamen.any((name) => name?.trim().toLowerCase() == klein);
  }
}
