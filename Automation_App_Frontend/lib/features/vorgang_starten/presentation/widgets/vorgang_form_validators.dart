import 'package:reactive_forms/reactive_forms.dart';

// Das Kennzeichen steht nicht mehr hier: Prüfung, Meldung und Normalisierung
// liegen bei `KennzeichenField` (`core/general_widgets/form/`) — ein Baustein
// für jede Stelle, an der ein Kennzeichen erfasst wird.

// Unfalluhrzeit im 24-Stunden-Format, z. B. "14:05" (Stunde ein- oder zweistellig).
final _uhrzeitRegExp = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');

const uhrzeitHinweis = 'Im Format HH:MM angeben, z. B. 14:05';

/// Prüft das Uhrzeit-Format, lässt leere Werte aber zu (Feld ist optional).
Map<String, dynamic>? uhrzeitValidator(AbstractControl<dynamic> control) {
  final value = (control.value as String?)?.trim() ?? '';
  if (value.isEmpty || _uhrzeitRegExp.hasMatch(value)) {
    return null;
  }
  return {ValidationMessage.pattern: true};
}

final uhrzeitMessages = {
  ValidationMessage.pattern: (Object _) => uhrzeitHinweis,
};

// Polizeiliche Vorgangsnummer, z. B. "VU/1234567/2026"
// (Kürzel/Ziffernfolge/vierstelliges Jahr).
final _vorgangsnummerRegExp = RegExp(
  r'^[A-ZÄÖÜ]{1,5}/\d{1,9}/\d{4}$',
  caseSensitive: false,
);

const vorgangsnummerHinweis = 'Format: VU/1234567/2026';

/// Prüft die Vorgangsnummer, lässt leere Werte aber zu (Feld ist optional).
Map<String, dynamic>? vorgangsnummerValidator(
  AbstractControl<dynamic> control,
) {
  final value = (control.value as String?)?.trim() ?? '';
  if (value.isEmpty || _vorgangsnummerRegExp.hasMatch(value)) {
    return null;
  }
  return {ValidationMessage.pattern: true};
}

final vorgangsnummerMessages = {
  ValidationMessage.pattern: (Object _) => vorgangsnummerHinweis,
};
