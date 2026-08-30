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
}
