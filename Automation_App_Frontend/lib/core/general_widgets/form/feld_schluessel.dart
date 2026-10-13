import 'package:flutter/widgets.dart';

/// Der Key, den jedes Formularfeld mit `formControlName` automatisch trägt.
///
/// Ein leeres Textfeld ist über seinen Text nicht greifbar, und die Beschriftung
/// reicht nicht, wo mehrere Felder ähnlich heißen. Der Key `feld-<Name>` macht
/// jedes Feld für Widget-Tests (`find.byKey`) und für die Bedienung per
/// Marionette eindeutig ansprechbar — ohne dass an der Oberfläche etwas zu
/// sehen ist. Er sitzt auf dem innersten `TextField` (siehe
/// `ReactiveTextEingabe`), dort, wo auch Text eingegeben wird.
abstract final class FeldSchluessel {
  static const String praefix = 'feld-';

  /// Der Key zu [formControlName]; `null` für ein Feld ohne Namen (dann hängt
  /// es an einem direkt übergebenen `FormControl`).
  static Key? fuer(String? formControlName) {
    if (formControlName == null || formControlName.isEmpty) return null;
    return ValueKey<String>('$praefix$formControlName');
  }
}
