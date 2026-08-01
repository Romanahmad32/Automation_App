import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';

/// Heuristiken, die aus den (frei definierten) Vorlagenfeldern die für Ablage
/// und Dateiname benötigten Werte herauslesen. Alles ist Best-Effort: Findet
/// die App nichts, gibt sie null/leere Vorschläge zurück und der Nutzer trägt
/// im Speicherschritt selbst ein.

/// Ursachendatum (Unfalldatum) aus den Formulardaten: bevorzugt ein Datumsfeld,
/// dessen Label nach Unfall/Ursache/Schaden/Datum aussieht; sonst das erste
/// Datumsfeld mit Wert.
String? ursachendatumAusFormular(List<FieldData> fields,
    Map<String, String> data,) {
  final datumsfelder = fields
      .where((f) => f.inputType == InputType.date)
      .toList();

  bool hatWert(FieldData f) =>
      (data[f.label]
          ?.trim()
          .isNotEmpty ?? false);

  // 1. Stark sprechende Labels (Unfall/Ursache/Schaden) zuerst — sie schlagen
  //    ein bloßes „Geburtsdatum", das ebenfalls „datum" enthält.
  for (final f in datumsfelder) {
    final l = f.label.toLowerCase();
    if ((l.contains('unfall') ||
        l.contains('ursache') ||
        l.contains('schaden')) &&
        hatWert(f)) {
      return data[f.label]!.trim();
    }
  }
  // 2. Sonst ein generisches „…datum"-Feld.
  for (final f in datumsfelder) {
    if (f.label.toLowerCase().contains('datum') && hatWert(f)) {
      return data[f.label]!.trim();
    }
  }
  // 3. Sonst das erste gefüllte Datumsfeld.
  for (final f in datumsfelder) {
    if (hatWert(f)) return data[f.label]!.trim();
  }
  return null;
}

/// Kennzeichen aus den Formulardaten (Label enthält „kennzeichen").
String? kennzeichenAusFormular(Map<String, String> data) {
  for (final entry in data.entries) {
    if (entry.key.toLowerCase().contains('kennzeichen') &&
        entry.value
            .trim()
            .isNotEmpty) {
      return entry.value.trim();
    }
  }
  return null;
}

/// Best-Effort-Stammdaten des Mandanten aus den Formularfeldern — als
/// Vorbelegung beim Anlegen eines neuen Mandanten im Speicherschritt.
typedef FormularMandantDaten = ({
String vorname,
String nachname,
String strasseHausnummer,
String postleitzahl,
String ort,
String emailAdresse,
String telefonnummer,
});

FormularMandantDaten mandantDatenAusFormular(Map<String, String> data) {
  String suche(List<String> stichworte, {List<String> ausschluss = const []}) {
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      if (ausschluss.any(key.contains)) continue;
      if (stichworte.any(key.contains) && entry.value
          .trim()
          .isNotEmpty) {
        return entry.value.trim();
      }
    }
    return '';
  }

  // „Mandant" hat Vorrang vor allgemeinem „Name", um Versicherungs-/Kanzleifelder
  // zu meiden.
  const fremd = ['versicherung', 'kanzlei', 'gegner', 'anwalt'];

  var vorname = suche(['vorname'], ausschluss: fremd);
  var nachname = suche(['nachname', 'familienname'], ausschluss: fremd);

  if (vorname.isEmpty && nachname.isEmpty) {
    final gesamt = suche(['mandant'], ausschluss: fremd).isNotEmpty
        ? suche(['mandant'], ausschluss: fremd)
        : suche(['name'], ausschluss: [...fremd, 'vorname', 'nachname']);
    if (gesamt.isNotEmpty) {
      final teile = gesamt.split(RegExp(r'\s+'));
      if (teile.length > 1) {
        vorname = teile.first;
        nachname = teile.sublist(1).join(' ');
      } else {
        nachname = gesamt;
      }
    }
  }

  return (
  vorname: vorname,
  nachname: nachname,
  strasseHausnummer: suche([
    'straße',
    'strasse',
    'anschrift',
    'adresse',
  ], ausschluss: fremd),
  postleitzahl: suche(['plz', 'postleitzahl'], ausschluss: fremd),
  ort: suche(['ort', 'wohnort', 'stadt'], ausschluss: fremd),
  emailAdresse: suche(['mail'], ausschluss: fremd),
  telefonnummer: suche(['telefon', 'tel.'], ausschluss: fremd),
  );
}

/// Baut den Ergebnis-Dateinamen aus dem Vorlagen-Dateinamen und dem
/// Ursachendatum nach dem Schema `Vorlagename Datum` (ohne Datum nur der
/// Vorlagename).
String baueDateiname(String wordVorlagePfad, String? ursachendatum) {
  final dateiMitEndung = wordVorlagePfad
      .split(RegExp(r'[\\/]'))
      .last;
  final basis = dateiMitEndung.replaceAll(
    RegExp(r'\.docx?$', caseSensitive: false),
    '',
  );
  final datum = ursachendatum?.trim() ?? '';
  return datum.isEmpty ? basis : '$basis $datum';
}
