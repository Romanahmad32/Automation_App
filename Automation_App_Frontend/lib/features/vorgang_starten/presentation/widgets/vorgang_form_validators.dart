import 'package:reactive_forms/reactive_forms.dart';

// Kennzeichen werden mit Bindestrich angegeben, z. B. "HG-E 1427"
// (optional E/H-Suffix für Elektro-/Oldtimer-Kennzeichen).
final _kennzeichenRegExp = RegExp(
  r'^[A-ZÄÖÜ]{1,3}-[A-Z]{1,2}\s?\d{1,4}\s?[EH]?$',
  caseSensitive: false,
);

const kennzeichenHinweis = 'Mit Bindestrich angeben, z. B. HG-E 1427';

/// Prüft, ob ein (nicht-leerer) String dem Kennzeichen-Format entspricht.
/// Für Eingaben außerhalb von reactive_forms (z. B. Chip-Editoren).
bool istGueltigesKennzeichen(String value) =>
    _kennzeichenRegExp.hasMatch(value.trim());

/// Prüft das Kennzeichen-Format, lässt leere Werte aber zu
/// (Pflicht regelt der Required-Validator des jeweiligen Feldes).
Map<String, dynamic>? kennzeichenValidator(AbstractControl<dynamic> control) {
  final value = (control.value as String?)?.trim() ?? '';
  if (value.isEmpty || _kennzeichenRegExp.hasMatch(value)) {
    return null;
  }
  return {ValidationMessage.pattern: true};
}

final kennzeichenMessages = {
  ValidationMessage.pattern: (Object _) => kennzeichenHinweis,
};

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
Map<String, dynamic>? vorgangsnummerValidator(AbstractControl<dynamic> control) {
  final value = (control.value as String?)?.trim() ?? '';
  if (value.isEmpty || _vorgangsnummerRegExp.hasMatch(value)) {
    return null;
  }
  return {ValidationMessage.pattern: true};
}

final vorgangsnummerMessages = {
  ValidationMessage.pattern: (Object _) => vorgangsnummerHinweis,
};
