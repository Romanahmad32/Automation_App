import 'package:automation_app/features/vorgaenge/domain/services/kennzeichen_normalisierung.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Fehlerschlüssel von [kennzeichenFeldValidator]. Eigener Schlüssel statt
/// `ValidationMessage.pattern`: An einem Vorlagenfeld können mehrere
/// Formatprüfungen hängen, und ein geteilter Schlüssel liesse deren Meldungen
/// einander überschreiben.
const kennzeichenFehler = 'kennzeichen';

/// Die Meldung dazu — sie **nennt die Konvention mit Beispiel**, statt „ungültig"
/// zu sagen: `HG-E 1427` erklärt in vier Zeichen, was drei Sätze bräuchten.
const kennzeichenMeldung = 'Kennzeichen wie HG-E 1427 eingeben';

/// Meldungen für ein Kennzeichenfeld, zum Hereingeben in das Eingabefeld.
Map<String, String Function(Object)> get kennzeichenMeldungen => {
  kennzeichenFehler: (Object _) => kennzeichenMeldung,
};

/// Prüft ein Kennzeichenfeld einer Formularvorlage (`InputType.kennzeichen`).
/// Leere Werte sind gültig — ob das Feld gefüllt sein muss, entscheidet der
/// Pflicht-Validator daneben.
///
/// **Nicht** derselbe wie `kennzeichenValidator` in
/// `vorgang_starten/presentation/widgets/vorgang_form_validators.dart`, und der
/// Unterschied ist Absicht: Dort wird ein Kennzeichen *erfasst*, dort gilt die
/// Schreibweise mit Bindestrich. Hier wird ein Vorlagenfeld ausgefüllt, dessen
/// Werte aus mehreren Beständen kommen und über den Auswahldialog ohnehin durch
/// `normalizeKennzeichen` laufen — beanstandet wird deshalb nur, was sich als
/// Kennzeichen überhaupt nicht lesen lässt ([istKennzeichen]). Eine strengere
/// Prüfung wäre hier eine Sackgasse: Sie beanstandete einen Wert, den die App
/// selbst aus dem Register angeboten hat.
Map<String, dynamic>? kennzeichenFeldValidator(
  AbstractControl<dynamic> control,
) {
  final wert = (control.value as String?)?.trim() ?? '';
  if (wert.isEmpty || istKennzeichen(wert)) return null;
  return {kennzeichenFehler: true};
}
