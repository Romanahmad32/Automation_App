import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/initial_template_form.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der veränderliche Stand des Vorlageneditors: die [FormGroup], die Feldliste
/// und die beiden Word-Pfade — samt jeder Änderung daran.
///
/// Aus der Detailseite herausgezogen (#104), wie zuvor schon
/// `ZuordnungsAktionen` und `FeldAenderungen`: Die Seite stand am Zeilenbudget,
/// und die folgenden Stufen setzen genau hier an (Stand anzeigen,
/// Zweispaltigkeit, Datei-zuerst-Ablauf). Was übrig bleibt, ist die Seite als
/// Aufbau — jeder Zustand liegt hier.
///
/// **Keine Widget-Abhängigkeit**: Die Methoden ändern nur diesen Stand und
/// geben nichts Anzeigbares zurück; die Seite ruft sie und baut danach mit
/// `setState` neu auf. So lässt sich jede Mutation ohne Tester prüfen.
///
/// Die Objekte sind **veränderlich und geteilt**: [fields] ist dieselbe Liste,
/// die die Karten zu sehen bekommen, [formGroup] dasselbe Formular. Wer hier
/// etwas ändert, ändert es überall — genau darauf bauen die Wache
/// (`VorlagenVerlassenWache`) und die Chips auf.
class VorlagenBearbeitung {
  VorlagenBearbeitung({
    required this.formGroup,
    required this.fields,
    required this.nextFieldIndex,
    required this.pfadOhneAuflistung,
    required this.pfadMitAuflistung,
  });

  /// Der Ausgangsstand zu einer bestehenden Vorlage — oder zu keiner, dann ist
  /// alles leer (Anlegen-Modus).
  factory VorlagenBearbeitung.fuer(FormTemplate? vorlage) {
    final anfang = InitialTemplateForm.fromTemplate(vorlage);
    return VorlagenBearbeitung(
      formGroup: anfang.formGroup,
      fields: [...anfang.fields],
      nextFieldIndex: anfang.nextFieldIndex,
      pfadOhneAuflistung: vorlage?.wordFilePathOhneAuflistung,
      pfadMitAuflistung: vorlage?.wordFilePathMitAuflistung,
    );
  }

  /// Trägt den Vorlagennamen (`templateName`) und je Feld ein Control unter
  /// dem Schlüssel, der in `FieldData.label` steht.
  final FormGroup formGroup;

  final List<FieldData> fields;

  String? pfadOhneAuflistung;
  String? pfadMitAuflistung;

  /// Der nächste freie Control-Schlüssel. Er wird nur hochgezählt, nie
  /// nachgerechnet: Ein gelöschtes Feld gibt seinen Schlüssel nicht zurück,
  /// sonst zeigten zwei Felder nacheinander auf dasselbe Control.
  int nextFieldIndex;

  String? pfad(TemplateFileSlot slot) => slot == TemplateFileSlot.ohneAuflistung
      ? pfadOhneAuflistung
      : pfadMitAuflistung;

  /// Verknüpft [pfad] mit [slot] — `null` entfernt die Verknüpfung. Die beiden
  /// Dateien sind gleichwertig; keine ist die zweite oder optionale.
  void setzePfad(TemplateFileSlot slot, String? pfad) {
    if (slot == TemplateFileSlot.ohneAuflistung) {
      pfadOhneAuflistung = pfad;
    } else {
      pfadMitAuflistung = pfad;
    }
  }

  /// Der Feldname zu einem Control-Schlüssel (`field_0`, …) — **die eine**
  /// Stelle, die ihn auflöst. Er steht im Wert des Controls, nicht in
  /// `FieldData.label`: Dort liegt, solange die Seite offen ist, nur der
  /// Schlüssel selbst (siehe FEATURE.md).
  String? feldname(String controlKey) =>
      formGroup.control(controlKey).value as String?;

  /// Die aktuell eingetragenen Feldnamen, in der Reihenfolge der Felder.
  List<String?> get feldnamen => [
    for (final feld in fields) feldname(feld.label),
  ];

  /// Legt ein Feld an: ein Control für den Namen und ein [FieldData], das
  /// darauf zeigt.
  ///
  /// Feldtyp und Datenquelle werden aus [name] **vorgeschlagen** — sichtbar im
  /// Dropdown und änderbar, nichts wird stillschweigend gebunden (§1.3).
  void feldHinzufuegen({String? name, bool pflicht = false}) {
    final schluessel = 'field_${nextFieldIndex++}';
    formGroup.addAll({
      schluessel: FormControl<String>(
        value: name,
        validators: [Validators.required],
      ),
    });
    fields.add(
      FeldDatenquelleErkennung.neuesFeld(
        order: fields.length,
        controlKey: schluessel,
        platzhalter: name,
        required: pflicht,
      ),
    );
  }

  /// „Alle übernehmen" (#35 Teil 3): [platzhalter] kommt bereits gefiltert
  /// herein ([VorlagenStand.platzhalterOhneFeld] bzw.
  /// `PlatzhalterUebernahme.uebernehmbare`) — hier entsteht daraus je ein
  /// Pflichtfeld. Gefahrlos, weil die Pflicht beim Ausfüllen je gewählter
  /// Word-Datei abgeleitet wird und ein Feld ohne Platzhalter dort nichts
  /// sperrt.
  void alleUebernehmen(List<String> platzhalter) {
    for (final name in platzhalter) {
      feldHinzufuegen(name: name, pflicht: true);
    }
  }

  /// Zieht das Feld von [alterIndex] nach [neuerIndex] — die Zählweise von
  /// `ReorderableListView`: Der Zielindex zählt die Lücke **vor** dem
  /// Herausnehmen.
  void verschiebe(int alterIndex, int neuerIndex) {
    if (neuerIndex > alterIndex) neuerIndex--;
    final feld = fields.removeAt(alterIndex);
    fields.insert(neuerIndex, feld);
  }

  /// Was der Vorlage nach dem aktuellen Stand noch fehlt — die eine Rechnung
  /// über beide Word-Dateien (#104).
  ///
  /// [zustand] liefert die gelesenen Platzhalter je Slot; was noch lädt oder
  /// fehlschlug, kommt als `null` herein und macht den Stand ausdrücklich
  /// unvollständig ([VorlagenStand.platzhalterUnbekannt]) statt still falsch.
  VorlagenStand stand(TemplatePlaceholdersState zustand) {
    List<String>? gelesen(TemplateFileSlot slot) =>
        switch (zustand.forSlot(slot)) {
          SlotPlaceholdersLoaded(placeholders: final erkannt) => erkannt,
          _ => null,
        };
    return VorlagenStand.bestimme(
      hatDateiOhne: pfadOhneAuflistung != null,
      hatDateiMit: pfadMitAuflistung != null,
      platzhalterOhne: gelesen(TemplateFileSlot.ohneAuflistung),
      platzhalterMit: gelesen(TemplateFileSlot.mitAuflistung),
      feldnamen: feldnamen,
    );
  }
}
