import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/form/form_wert_beobachter.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/verwendete_felder.dart';
import 'package:automation_app/features/word_automation/domain/services/datenquelle_vorschlaege.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_feld.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/kennzeichen_feld_validator.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/nicht_verwendete_felder.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/pflichtfelder_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

class FormTemplateBuilder extends StatelessWidget {
  final FormTemplate? formTemplate;
  final Widget? submitButtonLabel;
  final void Function(Map<String, String>)? onSubmitted;

  /// Vorbelegte Werte je Feldname (z. B. aus der Zentralruf-Antwort);
  /// sichtbar und vom Nutzer änderbar.
  final Map<String, String> initialValues;

  /// Herkunft je vorbelegtem Feldname (z. B. „aus der Zentralruf-Antwort"),
  /// als Hinweis unter dem Feld angezeigt — der Anwalt sieht so je Feld,
  /// welchem Datenbestand er vertraut, und erkennt falsche Vorbelegungen
  /// sofort (Punkt 7 des Verbesserungsplans).
  final Map<String, String> initialValueQuellen;

  /// Bereits getippte, noch nicht abgesendete Werte. Sie haben Vorrang vor
  /// [initialValues]: Was der Anwalt selbst eingetragen hat, darf eine
  /// Vorbelegung nicht überschreiben.
  ///
  /// Anders als [initialValues] steckt dieser Stand **nicht** im Schlüssel der
  /// FormGroup — sonst setzte sich das Formular beim Tippen selbst zurück. Er
  /// wirkt nur, wenn die Gruppe ohnehin neu gebaut wird.
  final Map<String, String> erfassteWerte;

  /// Wird entprellt mit dem vollständigen Tippstand gerufen. Ohne Rückmeldung
  /// (null) läuft kein Beobachter mit.
  final void Function(Map<String, String>)? onWerteGeaendert;

  /// Erhöhen erzwingt einen Neuaufbau der FormGroup. Nötig, wenn sich **nur**
  /// die einzusetzenden Werte geändert haben ([erfassteWerte]) — die stehen
  /// bewusst nicht im Schlüssel, also merkte das Formular sonst nichts davon.
  /// Genau der Fall beim übernommenen Entwurf.
  final int aufbauMarke;

  /// Wird mit dem Feld gerufen, dessen Stiftsymbol angeklickt wurde. Ohne
  /// Rückmeldung (null) zeigt das Formular keine Stifte — die freie Erfassung
  /// und die Vorschau kommen ohne aus.
  final void Function(FieldData)? onFeldBearbeiten;

  /// Die {{Platzhalter}} der gerade gewählten Word-Datei. Pflicht ist ein Feld
  /// nur, wenn sein Name hier vorkommt — je Variante abgeleitet statt global
  /// gespeichert (#35 Teil 2): Ein Feld, das nur in der Auflistungs-Datei
  /// steht, blockiert so nie das HGN-Schreiben.
  ///
  /// Null heißt: keine Ableitung — jede markierte Pflicht gilt (der Weg der
  /// freien Erfassung ohne bekannte Datei). Die leere Menge heißt dagegen:
  /// nichts ist Pflicht — sie ist der richtige Wert, solange die Platzhalter
  /// (noch) nicht gelesen werden konnten („solange nichts bekannt ist: nicht
  /// sperren").
  ///
  /// Dieselbe Menge entscheidet auch, welche Felder **oben** stehen (#82,
  /// [VerwendeteFelder]) — dort fällt der Zweifelsfall aber andersherum aus:
  /// ist nichts bekannt, wird alles gezeigt.
  final Set<String>? aktivePlatzhalter;

  /// Bekannte Werte je Feldname, unter denen der Anwalt wählen darf (#17) —
  /// gerechnet von `DatenquelleVorschlaege` und hier nur durchgereicht.
  ///
  /// Nicht zu verwechseln mit [initialValues]: Das ist der *eine* Wert, mit dem
  /// ein Feld belegt wird; dies sind die, unter denen es keine eindeutige Wahl
  /// gibt (drei Fahrzeuge des Mandanten). Beides kann an einem Feld gleichzeitig
  /// stehen: vorbelegt mit dem naheliegenden Wert, umschaltbar auf die anderen.
  final Map<String, List<FeldVorschlag>> vorschlaege;

  const FormTemplateBuilder({
    super.key,
    required this.formTemplate,
    this.submitButtonLabel,
    this.onSubmitted,
    this.initialValues = const {},
    this.initialValueQuellen = const {},
    this.erfassteWerte = const {},
    this.onWerteGeaendert,
    this.aufbauMarke = 0,
    this.onFeldBearbeiten,
    this.aktivePlatzhalter,
    this.vorschlaege = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (formTemplate == null) {
      return const SizedBox.shrink();
    }

    // Der Schlüssel bestimmt, wann die FormGroup neu gebaut wird: bei einer
    // anderen Vorlage, bei geänderten Feldern, bei neuer Vorbelegung und bei
    // anderen Platzhaltern (von ihnen hängen die Pflicht-Validatoren ab).
    return ReactiveFormBuilder(
      key: ValueKey(
        '${formTemplate!.id}#$aufbauMarke#$_feldSignatur#'
        '$_initialValuesSignature#$_platzhalterSignatur',
      ),
      form: () => FormGroup(
        Map.fromEntries(
          formTemplate!.fields.map((e) {
            // Ein eingeklapptes Feld (#82) darf dieses Schreiben weder
            // blockieren noch heimlich mitreden — beides hängt an derselben
            // Frage wie seine Sichtbarkeit:
            //
            // * **Keine Formatprüfung.** Ihr Fehler wäre unsichtbar (das
            //   Control ist zugeklappt nicht gebaut) und `PflichtfelderHinweis`
            //   meldet nur `required`: der Knopf stünde ohne erkennbaren Grund
            //   tot da — genau das, was #35 Teil 3 beseitigt hat.
            // * **Keine erfundene Vorbelegung.** Das heutige Datum ist als
            //   *sichtbarer* Vorschlag gedacht; zugeklappt liefe es
            //   unkorrigierbar über `ursachendatumAusFormular` in den
            //   Dateinamen. Selbst Getipptes bleibt unberührt — es steht in
            //   [erfassteWerte] und hat ohnehin Vorrang.
            final verwendet = VerwendeteFelder.wirdVerwendet(
              e.label,
              aktivePlatzhalter,
            );
            return MapEntry(
              e.label,
              FormControl<String>(
                // Selbst Getipptes zuerst, dann die Vorgangsdaten
                // (Zentralruf-Antwort); sonst Datumsfelder mit heutigem Datum
                // vorbelegen – sichtbar und änderbar, statt es beim Erzeugen
                // unsichtbar einzusetzen.
                value:
                    erfassteWerte[e.label] ??
                    initialValues[e.label] ??
                    (e.inputType == InputType.date && verwendet
                        ? GermanDateField.formatDate(_defaultDateFor(e))
                        : null),
                validators: [
                  if (_istPflicht(e)) Validators.required,
                  if (e.inputType == InputType.date && verwendet)
                    GermanDateField.validator(),
                  if (e.inputType == InputType.kennzeichen && verwendet)
                    Validators.delegate(kennzeichenFeldValidator),
                ],
              ),
            );
          }),
        ),
      ),
      builder: (context, formGroup, child) {
        // Oben steht, was dieses Schreiben braucht; der Rest wandert unter die
        // aufklappbare Zeile (#82). Beides in der Reihenfolge der Vorlage.
        final aufteilung = VerwendeteFelder.teile(
          formTemplate!.fields,
          aktivePlatzhalter,
        );
        final inhalt = Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            spacing: 16,
            children: [
              ...aufteilung.verwendet.map(_buildZeile),
              if (aufteilung.uebrig.isNotEmpty)
                NichtVerwendeteFelder(
                  felder: [
                    for (final field in aufteilung.uebrig) _buildZeile(field),
                  ],
                ),
              const SizedBox(height: 8),
              // Sagt, welche leeren Pflichtfelder den Knopf sperren, und
              // springt beim Anklicken hin — statt eines kommentarlos toten
              // Knopfs (#35 Teil 3).
              PflichtfelderHinweis(
                pflichtFelder: [
                  for (final field in formTemplate!.fields)
                    if (_istPflicht(field)) field.label,
                ],
              ),
              ReactiveFormConsumer(
                builder: (context, formGroup, child) {
                  return CustomRectangularButton(
                    label: submitButtonLabel ?? const Text('Formular absenden'),
                    onPressed: formGroup.valid
                        ? () {
                            final data = formGroup.value.map(
                              (key, value) =>
                                  MapEntry(key, value?.toString() ?? ''),
                            );
                            onSubmitted?.call(data);
                          }
                        : null,
                  );
                },
              ),
            ],
          ),
        );
        final melden = onWerteGeaendert;
        if (melden == null) return inhalt;
        return FormWertBeobachter(
          formGroup: formGroup,
          onWerteGeaendert: melden,
          child: inhalt,
        );
      },
    );
  }

  /// Stabile Signatur der Vorbelegung: gleiche Werte → gleicher Key, sonst
  /// würde jedes Rebuild das Formular (und damit Nutzereingaben) zurücksetzen.
  String get _initialValuesSignature =>
      (initialValues.entries.map((e) => '${e.key}=${e.value}').toList()..sort())
          .join('|');

  /// Signatur dessen, was die FormGroup aus den Feldern macht: Name, Typ und
  /// Pflichtangabe. Fehlte sie im Schlüssel, überlebte die alte Gruppe eine
  /// bearbeitete Vorlage — und dann zeigte das Formular zwar die neuen Felder,
  /// arbeitete aber mit den alten Controls: Ein auf „nicht erforderlich"
  /// gestelltes Feld blieb still ein Pflichtfeld (der Knopf ohne erkennbaren
  /// Grund gesperrt), ein umbenanntes ließ `formControlName` ins Leere greifen
  /// (`FormControlNotFoundException`, roter Bildschirm).
  String get _feldSignatur => formTemplate!.fields
      .map((e) => '${e.label}:${e.inputType.value}:${e.required}')
      .join('|');

  /// Das Feld, bei Bedarf mit dem Stift daneben. Der Stift sitzt **am Feld**
  /// und nicht in einer Werkzeugleiste: Er soll dort sein, wo der Anwalt gerade
  /// stutzt („dieses Feld will ich gar nicht ausfüllen müssen").
  Widget _buildZeile(FieldData field) {
    final bearbeiten = onFeldBearbeiten;
    if (bearbeiten == null) return _buildField(field);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildField(field)),
        Padding(
          // Auf die Höhe des Eingabefelds gerückt, nicht auf die der Zeile:
          // Unter dem Feld steht oft noch eine Hinweiszeile.
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Einstellung des Felds „${field.label}"',
            onPressed: () => bearbeiten(field),
          ),
        ),
      ],
    );
  }

  /// Pflicht ist ein Feld nur, wenn es so markiert ist, die App seinen
  /// Platzhalter nicht selbst füllt (#35 Teil 1) **und** sein Name in der
  /// gerade gewählten Word-Datei vorkommt (#35 Teil 2, [aktivePlatzhalter]).
  ///
  /// Der Namensvergleich läuft ohne Groß-/Kleinschreibung — die Ersetzung im
  /// Backend arbeitet mit `RegexOptions.IgnoreCase`; wiche die Prüfung davon
  /// ab, widersprächen sich Formular und Dokument.
  bool _istPflicht(FieldData field) =>
      field.required &&
      !AppEigenePlatzhalter.istAppEigen(field.label) &&
      _kommtInAktiverDateiVor(field.label);

  /// Anders als bei der Sichtbarkeit ([VerwendeteFelder.wirdVerwendet]) macht
  /// die **leere** Menge hier nichts zur Pflicht: Was nicht gelesen werden
  /// konnte, darf nicht sperren.
  bool _kommtInAktiverDateiVor(String label) {
    final platzhalter = aktivePlatzhalter;
    if (platzhalter == null) return true;
    return VerwendeteFelder.enthaelt(platzhalter, label);
  }

  /// Signatur der Platzhaltermenge für den FormGroup-Schlüssel: Ändert sie
  /// sich, ändern sich die Pflicht-Validatoren — die Gruppe muss neu entstehen.
  /// Damit das keine Eingaben kostet, reicht der Aufrufer die Menge **vor**
  /// dem ersten Aufbau herein statt sie nachzuschieben.
  String get _platzhalterSignatur {
    final platzhalter = aktivePlatzhalter;
    if (platzhalter == null) return '?';
    // Genauso normalisiert wie in `VerwendeteFelder.enthaelt` (trim **und**
    // Kleinschreibung): Sonst gälten zwei Mengen, die die Zuordnung für
    // gleich hält, hier als verschieden — die FormGroup entstünde neu und
    // nähme den Tippstand der letzten Sekunden mit.
    return (platzhalter.map((name) => name.trim().toLowerCase()).toList()
          ..sort())
        .join(',');
  }

  /// Das Feld selbst: Aussehen, Auswahlhilfe und die Meldungen der
  /// Validatoren, die oben an der FormGroup hängen.
  Widget _buildField(FieldData field) => AusfuellFeld(
    field: field,
    helperText: _helperText(field),
    helperMaxLines: _helperZeilen,
    validationMessages: _istPflicht(field)
        ? {
            ValidationMessage.required: (Object _) =>
                '${field.label} ist ein Pflichtfeld',
          }
        : const {},
    vorschlaege: vorschlaege[field.label] ?? const [],
  );

  /// Die Hinweiszeile darf umbrechen. Das Formular steht in der 450 px breiten
  /// Spalte des Ausfüllschritts, und der Stift nimmt ihr noch einmal rund 48 px
  /// ab: „* Pflichtfeld · Vorbelegt aus dem letzten Schreiben" passt dort in
  /// keine Zeile. Mit der Material-Vorgabe (eine Zeile) wurde daraus ein „…",
  /// und der Anwalt sah nicht mehr, welchem Bestand er gerade vertraut — genau
  /// das, wofür die Zeile da ist.
  static const _helperZeilen = 2;

  /// Hinweiszeile unter dem Feld: Pflichtfeld-Markierung und — falls das Feld
  /// vorbelegt wurde — die Herkunft des Werts.
  String? _helperText(FieldData field) {
    final quelle = initialValueQuellen[field.label];
    final pflicht = _istPflicht(field) ? '* Pflichtfeld' : null;
    if (quelle == null) return pflicht;
    final vorbelegt = 'Vorbelegt $quelle';
    return pflicht == null ? vorbelegt : '$pflicht · $vorbelegt';
  }

  /// Vorschlag für ein Datumsfeld: die am Feld eingestellte
  /// [DatumsVorbelegung], sonst die Namensregel als Rückfall. Was die beiden
  /// unterscheidet und warum hier kein [Duration] gerechnet wird, steht an der
  /// Entität.
  static DateTime _defaultDateFor(FieldData field) =>
      (field.vorbelegung ?? DatumsVorbelegung.ausFeldname(field.label))
          .anwendenAuf(DateTime.now());
}
