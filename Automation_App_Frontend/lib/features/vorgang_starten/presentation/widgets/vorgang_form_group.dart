import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut die FormGroup des „Vorgang starten"-Formulars mit allen Feldern,
/// Vorbelegungen und Validatoren. Die Pflicht der Unfall-Felder (Kennzeichen
/// Gegner, Unfalltag) hängt vom Rechtsgebiet ab und wird in der View dynamisch
/// gesetzt — hier stehen nur die rechtsgebietsunabhängigen Formatprüfungen.
FormGroup createVorgangForm() {
  return FormGroup({
    'auftragsnummer': FormControl<String>(
      validators: [Validators.required, Validators.number()],
    ),
    // Standardmäßig das aktuelle zweistellige Jahr (z. B. "26"); bleibt
    // bearbeitbar.
    'auftragsjahr': FormControl<String>(
      value: (DateTime.now().year % 100).toString().padLeft(2, '0'),
    ),
    // Häufigste Abteilung als Vorbelegung; bleibt änderbar.
    'abteilung': FormControl<String>(
      value: 'C03',
      validators: [Validators.required],
    ),
    // Unfall (nur bei Verkehrsrecht sichtbar/pflicht). Am Kennzeichen hängt
    // **kein** Formatvalidator: Ein E-Scooter trägt ein
    // Versicherungskennzeichen, ein Behördenwagen `THW-12345`, der Gegner
    // womöglich ein französisches — nichts davon passt ins Pkw-Schema, und
    // keines ist ein Grund, den Vorgang aufzuhalten (#130). `KennzeichenField`
    // normalisiert, was eindeutig ist, und merkt den Rest sichtbar an.
    'kennzeichenGegner': FormControl<String>(),
    'schadentag': FormControl<String>(
      validators: [
        GermanDateField.validator(
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        ),
      ],
    ),
    // Mandantendaten (Geschädigter).
    'mandantVorname': FormControl<String>(),
    'mandantNachname': FormControl<String>(),
    'mandantStrasse': FormControl<String>(),
    'mandantPlz': FormControl<String>(),
    'mandantOrt': FormControl<String>(),
    'mandantEmail': FormControl<String>(validators: [Validators.email]),
    'mandantTelefon': FormControl<String>(),
    'mandantKennzeichen': FormControl<String>(),
    // Unfallhergang (nur bei Verkehrsrecht).
    'unfallort': FormControl<String>(),
    'unfalluhrzeit': FormControl<String>(
      validators: [Validators.delegate(uhrzeitValidator)],
    ),
    'polizeiVorgangsnummer': FormControl<String>(
      validators: [Validators.delegate(vorgangsnummerValidator)],
    ),
    // Vorschau der resultierenden Referenz; wird automatisch befüllt, bis der
    // Anwender sie selbst bearbeitet.
    'referenz': FormControl<String>(),
  });
}

/// Anzeigenamen der Controls für die Sammelzeile über der Aktionsleiste
/// (`FormularFehlerHinweis`). Hier und nicht dort, weil die Control-Namen von
/// [createVorgangForm] stammen: Wer ein Feld umbenennt, sieht die Beschriftung
/// daneben stehen. Die Texte sind die Beschriftungen aus den Sektionen, nur
/// ohne deren Beispiel in Klammern — in einer Aufzählung zählt die Kürze.
const vorgangFeldBeschriftungen = {
  'auftragsnummer': 'Auftragsnummer',
  'auftragsjahr': 'Jahr',
  'abteilung': 'Abteilung',
  'kennzeichenGegner': 'Kennzeichen des Unfallgegners',
  'schadentag': 'Unfalldatum',
  'mandantVorname': 'Vorname',
  'mandantNachname': 'Nachname',
  'mandantStrasse': 'Straße und Hausnummer',
  'mandantPlz': 'PLZ',
  'mandantOrt': 'Ort',
  'mandantEmail': 'E-Mail',
  'mandantTelefon': 'Telefon',
  'mandantKennzeichen': 'Kfz-Kennzeichen des Mandanten',
  'unfallort': 'Unfallort',
  'unfalluhrzeit': 'Unfalluhrzeit',
  'polizeiVorgangsnummer': 'Polizei-Vorgangsnummer',
  'referenz': 'Referenz',
};
