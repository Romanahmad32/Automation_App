import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagenname_vorschlag.dart';
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
    this.istNeu = false,
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
      istNeu: vorlage == null,
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

  /// Hier entsteht eine **neue** Vorlage (`.fuer(null)`) — nicht dasselbe wie
  /// [istLeer]: Eine bestehende Vorlage kann feldlos sein, und eine neue hat
  /// nach dem ersten Einlesen schon Felder.
  ///
  /// Daran hängt der Ablauf „Datei zuerst": Nur beim Anlegen werden die
  /// gelesenen Platzhalter von selbst zu Feldern. In einer bestehenden Vorlage
  /// wäre dasselbe ein Eingriff in Handarbeit, die schon dasteht.
  final bool istNeu;

  /// Je Slot der **Pfad**, für den die Platzhalter schon automatisch zu
  /// Feldern geworden sind. Ohne dieses Gedächtnis liefe die Übernahme bei
  /// jedem erneuten Einlesen derselben Datei wieder an — und ein Feld, das der
  /// Anwalt inzwischen gelöscht hat, käme von selbst zurück.
  ///
  /// Gemerkt wird der Pfad und nicht bloß der Slot, weil ein **echter**
  /// Dateiwechsel den Slot wieder freigeben soll: „zuerst die falsche Datei
  /// gewählt" ist beim Anlegen der häufige Weg, und für die richtige Datei
  /// soll „Datei zuerst → Felder von selbst" weiter gelten. Dieselbe Datei
  /// noch einmal einzulesen gibt dagegen nichts frei.
  final Map<TemplateFileSlot, String?> automatischUebernommen = {};

  bool _nameVorgeschlagen = false;
  String? _nameVorschlag;
  String? _nameVorschlagQuelle;

  /// Die Vorlage hat noch kein einziges Feld — nicht dasselbe wie [istNeu]
  /// und nicht dasselbe wie [zeigtLeerzustand]: Nach dem ersten Einlesen ist
  /// eine neue Vorlage nicht mehr leer, und eine bestehende darf es sein.
  bool get istLeer => fields.isEmpty;

  /// Keine der beiden Word-Dateien ist verknüpft.
  bool get ohneDatei => pfadOhneAuflistung == null && pfadMitAuflistung == null;

  /// Die Seite zeigt statt des Editors die Auswahlseite „Womit fängt diese
  /// Vorlage an?" (`VorlagenLeerzustand`, #104 Stufe 3c/5).
  ///
  /// Nur beim **Anlegen**: Eine bestehende Vorlage ohne Datei ist ein Mangel,
  /// den `VorlagenStandBereich` benennt — ihren Namen und ihre Felder deshalb
  /// wegzublenden nähme dem Anwalt genau das, was er reparieren will.
  bool get zeigtLeerzustand => istNeu && !_auswahlAbgeschlossen;

  /// Der Anwalt hat die Auswahlseite mit „Weiter" verlassen.
  ///
  /// **Ein eigener Zustand und nicht aus [ohneDatei] abgeleitet** (bis Stufe 4
  /// war es das): Die Auswahl endet, wenn der Anwalt sie beendet, nicht wenn
  /// der erste Pfad steht. Sonst sprang die Seite nach der ersten Datei in den
  /// Editor, und die zweite — gleichwertige — Datei war nur noch dort zu
  /// verknüpfen.
  ///
  /// **Kein Rückweg.** Ist die Auswahl einmal abgeschlossen, kommt sie auch
  /// dann nicht wieder, wenn beide Dateien wieder entfernt werden: Dann stehen
  /// schon ein Name und Felder da, und „Womit fängt diese Vorlage an?" wäre
  /// eine Lüge über den Stand der Vorlage. Was dann fehlt, benennt
  /// `VorlagenStandBereich` — an derselben Stelle wie bei einer bestehenden
  /// Vorlage.
  bool get auswahlAbgeschlossen => _auswahlAbgeschlossen;

  bool _auswahlAbgeschlossen = false;

  /// „Weiter" auf der Auswahlseite — der einzige Weg in den Editor.
  void weiter() => _auswahlAbgeschlossen = true;

  /// Ob „Weiter" gedrückt werden darf: mindestens eine Datei verknüpft und
  /// kein Lesevorgang offen.
  ///
  /// Die wartende Datei ist der Grund für die zweite Bedingung: Die Felder
  /// entstehen erst, wenn ihre Platzhalter gelesen sind (`EinleseReaktion`).
  /// Wer währenddessen weiterklickt, sähe einen leeren Editor und gleich
  /// darauf eine Meldung über Felder, die er nicht angelegt hat.
  ///
  /// Ein **Lesefehler** hält nicht auf: Er steht in der Kachel, und die
  /// Vorlage lässt sich trotzdem einrichten — die Platzhalter sind dann eben
  /// von Hand zu benennen.
  bool weiterMoeglich(TemplatePlaceholdersState zustand) =>
      !ohneDatei &&
      !TemplateFileSlot.values.any(
        (slot) =>
            pfad(slot) != null &&
            zustand.forSlot(slot) is SlotPlaceholdersLoading,
      );

  /// Ob der Vorlagenname aus einem Dateinamen stammt und nicht vom Anwalt.
  /// Trägt den Hinweis „aus … vorgeschlagen" unter dem Namensfeld.
  bool get nameWurdeVorgeschlagen => _nameVorgeschlagen;

  /// Der zuletzt vorgeschlagene Name — null, solange nichts vorgeschlagen
  /// wurde. Er steht hier, damit [nameZeigtVorschlag] ihn vergleichen kann,
  /// ohne ihn neu zu rechnen.
  String? get nameVorschlag => _nameVorschlag;

  /// Der Dateiname, aus dem der Vorschlag stammt (`HGn.docx`) — null, solange
  /// nichts vorgeschlagen wurde.
  String? get nameVorschlagQuelle => _nameVorschlagQuelle;

  /// Im Namensfeld steht **noch** der Vorschlag, unverändert. Genau dann trägt
  /// die Namenskarte ihren Hinweis „Vorschlag aus … — bei Bedarf anpassen":
  /// Sobald der Anwalt ein Zeichen ändert, ist es sein Name, und ein Hinweis
  /// auf die Herkunft wäre falsch.
  bool get nameZeigtVorschlag =>
      _nameVorgeschlagen &&
      formGroup.control('templateName').value == _nameVorschlag;

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

  /// Schlägt den Vorlagennamen aus dem Dateinamen von [pfad] vor und liefert
  /// true, wenn er dadurch gesetzt wurde.
  ///
  /// **Nur in ein leeres Namensfeld.** Was der Anwalt getippt hat, gewinnt
  /// immer — auch gegen den besseren Vorschlag und auch, wenn er die Datei
  /// danach noch einmal tauscht (§1.3 „Vorschlagen statt entscheiden").
  /// Ergibt der Dateiname keinen Namen ([VorlagennameVorschlag.ausPfad] ist
  /// leer), passiert nichts.
  bool nameVorschlagen(String pfad) {
    final control = formGroup.control('templateName');
    final bisher = control.value as String?;
    if (bisher != null && bisher.trim().isNotEmpty) return false;
    final vorschlag = VorlagennameVorschlag.ausPfad(pfad);
    if (vorschlag.isEmpty) return false;
    control.updateValue(vorschlag);
    _nameVorgeschlagen = true;
    _nameVorschlag = vorschlag;
    _nameVorschlagQuelle = VorlagennameVorschlag.dateiname(pfad);
    return true;
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

  /// Legt zu [platzhalter] je ein Pflichtfeld an und liefert, wie viele es
  /// wurden. Gefahrlos pflichtig, weil die Pflicht beim Ausfüllen je gewählter
  /// Word-Datei abgeleitet wird und ein Feld ohne Platzhalter dort nichts
  /// sperrt.
  ///
  /// **Gefiltert wird hier**, über [PlatzhalterUebernahme.uebernehmbare]:
  /// keine app-eigenen Platzhalter (die füllt das Backend selbst und sie
  /// bekommen nie ein Feld), keine Namensgleichen, keine Doppelten. Der Filter
  /// steht hier und nicht beim Aufrufer, weil die Liste aus zwei Richtungen
  /// kommt — von der Stand-Karte bereits gefiltert (dann ist er wirkungslos)
  /// und beim ersten Einlesen einer neuen Vorlage roh aus dem Bloc.
  int felderAusPlatzhalternAnlegen(List<String> platzhalter) {
    final neu = PlatzhalterUebernahme.uebernehmbare(platzhalter, feldnamen);
    for (final name in neu) {
      feldHinzufuegen(name: name, pflicht: true);
    }
    return neu.length;
  }

  /// „Alle übernehmen" (#35 Teil 3) — der Knopf der Stand-Karte. Dieselbe
  /// Handlung wie [felderAusPlatzhalternAnlegen], nur ohne Zahl: Der Knopf
  /// zählt nicht, er legt an.
  void alleUebernehmen(List<String> platzhalter) =>
      felderAusPlatzhalternAnlegen(platzhalter);

  /// Ob die Platzhalter von [slot] von selbst zu Feldern werden dürfen: nur
  /// beim Anlegen einer neuen Vorlage ([istNeu]) und je **Datei** nur einmal.
  ///
  /// Verglichen wird gegen den vorgemerkten Pfad, nicht gegen den blossen
  /// Slot: Eine andere Datei fängt von vorn an, dieselbe nicht (siehe
  /// [automatischUebernommen]). `containsKey` statt eines Vergleichs auf
  /// `null`, weil „noch nie übernommen" und „für eine Vorlage ohne Pfad
  /// übernommen" zwei verschiedene Dinge sind.
  bool sollAutomatischUebernehmen(TemplateFileSlot slot) =>
      istNeu &&
      (!automatischUebernommen.containsKey(slot) ||
          automatischUebernommen[slot] != pfad(slot));

  /// Der Ablauf „Datei zuerst" in einem Aufruf: prüft
  /// [sollAutomatischUebernehmen], merkt die Datei vor und legt die Felder an
  /// — 0, wenn nichts zu tun war.
  ///
  /// Vorgemerkt wird **auch dann**, wenn keine Felder entstanden sind: Die
  /// Datei ist gelesen, und ein zweiter Anlauf brächte nur zurück, was der
  /// Anwalt inzwischen gelöscht hat.
  int automatischUebernehmen(TemplateFileSlot slot, List<String> platzhalter) {
    if (!sollAutomatischUebernehmen(slot)) return 0;
    automatischUebernommen[slot] = pfad(slot);
    return felderAusPlatzhalternAnlegen(platzhalter);
  }

  /// Zieht das Feld von [alterIndex] nach [neuerIndex] — die Zählweise von
  /// `onReorderItem`: Der Zielindex zählt die Stelle **nach** dem
  /// Herausnehmen, ist also schon fertig verrechnet.
  ///
  /// Bis Flutter 3.41 lief das über `onReorder`, dessen Zielindex die Lücke
  /// noch mitzählte — daher stand hier ein `if (neuerIndex > alterIndex)
  /// neuerIndex--;`. `onReorderItem` nimmt einem genau diese Korrektur ab;
  /// stünde sie noch hier, zöge sie ein zweites Mal ab und jedes Ziehen nach
  /// unten landete eine Stelle zu weit vorn.
  void verschiebe(int alterIndex, int neuerIndex) {
    final feld = fields.removeAt(alterIndex);
    fields.insert(neuerIndex, feld);
  }

  /// Entfernt das Feld an [index] samt seinem Control. Zu jedem Feld gehört
  /// eines, dessen Schlüssel in `FieldData.label` steht, solange die Seite
  /// offen ist — bliebe es stehen, hinge ein Pflicht-Validator ohne Feld im
  /// Formular und hielte den Speichern-Knopf grau.
  ///
  /// Die eine Stelle dafür: `FeldAenderungen.loeschen` (Löschknopf der Zeile)
  /// und [felderEntfernen] (Abgleich nach Dateiwechsel) rufen beide hier.
  void feldLoeschen(int index) {
    formGroup.removeControl(fields[index].label);
    fields.removeAt(index);
  }

  /// Entfernt die Felder mit diesen [namen] — der Weg des Abgleichs nach einem
  /// Dateiwechsel (`FeldAbgleich`, `AbgleichDialog`).
  ///
  /// Verglichen wird über den **aufgelösten** Feldnamen, ohne
  /// Groß-/Kleinschreibung und ohne Randleerzeichen, wie überall sonst.
  /// Rückwärts durch die Liste, damit die Indizes der noch zu prüfenden Felder
  /// gültig bleiben.
  void felderEntfernen(Iterable<String> namen) {
    final gesucht = {for (final name in namen) name.trim().toLowerCase()};
    if (gesucht.isEmpty) return;
    for (var i = fields.length - 1; i >= 0; i--) {
      final name = feldname(fields[i].label)?.trim().toLowerCase();
      if (name == null || !gesucht.contains(name)) continue;
      feldLoeschen(i);
    }
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
