import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut die FormGroup des „Vorgang starten"-Formulars mit allen Feldern,
/// Vorbelegungen und Validatoren.
///
/// Der ganze Unfallteil hängt am Rechtsgebiet und wird von der View gesetzt,
/// sobald sie es kennt ([setzeUnfallPruefungen]); hier steht davon nur der
/// Ausgangsstand — die Formatprüfungen, noch ohne Pflicht.
FormGroup createVorgangForm() {
  final form = FormGroup({
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
    // merkt sichtbar an, was auffällt; umgeschrieben wird der Wert hier nicht,
    // er geht wörtlich in die Referenz (§4.2).
    'kennzeichenGegner': FormControl<String>(),
    'schadentag': FormControl<String>(),
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
    'unfalluhrzeit': FormControl<String>(),
    'polizeiVorgangsnummer': FormControl<String>(),
    // Vorschau der resultierenden Referenz; wird automatisch befüllt, bis der
    // Anwender sie selbst bearbeitet.
    'referenz': FormControl<String>(),
  });
  // Ohne die Pflicht: Die hängt am Rechtsgebiet und wird von der View gesetzt,
  // sobald sie es kennt ([setzeUnfallPruefungen]).
  unfallFormatPruefungen().forEach((name, validatoren) {
    form.control(name)
      ..setValidators(validatoren)
      ..updateValueAndValidity();
  });
  return form;
}

/// Die **Formatprüfungen** der Unfall-Felder, genau einmal beschrieben: Zwei
/// Stellen brauchen sie — der Aufbau oben und [setzeUnfallPruefungen], wenn
/// das Rechtsgebiet sie zurückholt.
///
/// Eine Funktion und keine Konstante, weil `DateTime.now()` darin steckt: Eine
/// einmal berechnete Obergrenze veraltete in einer App, die tagelang offen
/// steht.
Map<String, List<Validator<dynamic>>> unfallFormatPruefungen() => {
  // Am Kennzeichen steht nie eine Formatprüfung — wieso, steht oben (#130).
  'kennzeichenGegner': const [],
  'schadentag': [
    GermanDateField.validator(
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    ),
  ],
  'unfallort': const [],
  'unfalluhrzeit': [Validators.delegate(uhrzeitValidator)],
  'polizeiVorgangsnummer': [Validators.delegate(vorgangsnummerValidator)],
};

/// Setzt die Prüfungen der Unfall-Felder; sie hängen am Rechtsgebiet.
///
/// Pflicht sind bei Verkehrsrecht das Kennzeichen des Gegners und der
/// Unfalltag — beide gehen in die Referenz und ins Zentralruf-Formular ein.
///
/// **Ausserhalb des Verkehrsrechts trägt keines der fünf einen Validator**,
/// auch keine Formatprüfung: Ihre beiden Abschnitte stehen dann nicht mehr auf
/// der Seite, die Controls aber weiter in der Gruppe. Eine `25:99`, aus dem
/// vorherigen Rechtsgebiet stehengeblieben, sperrte damit „Vorgang speichern",
/// ohne dass irgendwo ein Feld zu sehen wäre, das man berichtigen könnte —
/// genau der stumm gesperrte Knopf, den #130 abschafft. Dieselbe Regel wie
/// beim eingeklappten Vorlagenfeld (#82): Was nicht sichtbar ist, prüft nichts
/// und hält nichts auf. Die Werte bleiben stehen und gelten beim
/// Zurückwechseln wieder.
void setzeUnfallPruefungen(FormGroup form, {required bool istVerkehrsunfall}) {
  const pflichtfelder = ['kennzeichenGegner', 'schadentag'];
  final format = unfallFormatPruefungen();
  for (final name in vorgangVerkehrsFelder) {
    form.control(name)
      ..setValidators([
        if (istVerkehrsunfall) ...[
          if (pflichtfelder.contains(name)) Validators.required,
          ...format[name]!,
        ],
      ])
      ..updateValueAndValidity();
  }
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

/// Die Controls der beiden Abschnitte, die **nur bei Verkehrsrecht** auf der
/// Seite stehen (`UnfallSection`, `UnfallhergangSection`).
///
/// Genau diese fünf nimmt [setzeUnfallPruefungen] die Prüfung ab, sobald ihre
/// Abschnitte von der Seite verschwinden — warum, steht dort.
const vorgangVerkehrsFelder = [
  'kennzeichenGegner',
  'schadentag',
  'unfallort',
  'unfalluhrzeit',
  'polizeiVorgangsnummer',
];
