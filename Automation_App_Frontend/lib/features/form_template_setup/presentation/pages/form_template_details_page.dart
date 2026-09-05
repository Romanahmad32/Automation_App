import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/app_eigene_platzhalter_liste.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/einlese_reaktion.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_aenderungen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_abschnitt.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_fehler_melder.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slots.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_name_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_dateiwahl.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_editor_kopf.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_editor_layout.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_leerzustand.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_stand_bereich.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/zuordnungs_aktionen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_verlassen_wache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

@RoutePage()
class FormTemplateDetailsPage extends StatefulWidget
    implements AutoRouteWrapper {
  final FormTemplate? formTemplate; // Null = Create mode, Provided = Edit mode

  const FormTemplateDetailsPage({super.key, this.formTemplate});

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => getIt<FormTemplateDataBloc>()),
        BlocProvider(create: (context) => getIt<TemplatePlaceholdersBloc>()),
      ],
      child: this,
    );
  }

  @override
  State<FormTemplateDetailsPage> createState() =>
      _FormTemplateDetailsPageState();
}

class _FormTemplateDetailsPageState extends State<FormTemplateDetailsPage> {
  /// Der ganze veränderliche Stand des Editors. Die Seite hält ihn, ändert ihn
  /// aber nie selbst: Jede Mutation liegt in [VorlagenBearbeitung], hier steht
  /// nur das `setState` darum (#104).
  late final VorlagenBearbeitung _bearbeitung;

  /// Was auf ein fertig gelesenes Word-Dokument folgt — Felder anlegen und
  /// nach einem Dateiwechsel abgleichen (#104 Stufe 3c). Sie merkt sich den
  /// zuletzt gesehenen Stand und lebt deshalb so lange wie die Seite.
  late final EinleseReaktion _reaktion;

  // Helper getter to determine the current mode
  bool get isEditing => widget.formTemplate != null;

  @override
  void initState() {
    super.initState();
    _bearbeitung = VorlagenBearbeitung.fuer(widget.formTemplate);
    _reaktion = EinleseReaktion(
      onGeaendert: _neuAufbauen,
      // Während des Speicherns darf nichts aufgehen: Der Erfolgs-`pop` unten
      // träfe sonst den Dialog statt der Seite (siehe `VorlagenVerlassenWache`).
      gesperrt: () =>
          context.read<FormTemplateDataBloc>().state
              is SubmittingFormTemplateData,
    );

    // Bei bereits verknüpften Word-Dateien die Platzhalter direkt laden. Als
    // Schleife über beide Slots statt zweimal derselbe Block: Der Editor
    // behandelt sie durchweg gleich, und der Platz gehört hier dem, was die
    // Seite wirklich unterscheidet.
    for (final slot in TemplateFileSlot.values) {
      final pfad = _bearbeitung.pfad(slot);
      if (pfad == null) continue;
      context.read<TemplatePlaceholdersBloc>().add(
        LoadTemplatePlaceholders(pfad, slot),
      );
    }
  }

  /// Beide Wege der Zuordnung (#36) — sie arbeiten auf dem aktuellen Stand und
  /// werden deshalb je Klick frisch gebaut.
  ZuordnungsAktionen get _zuordnung => ZuordnungsAktionen.ausZustand(
    context.read<TemplatePlaceholdersBloc>().state,
    bearbeitung: _bearbeitung,
  );

  /// Alle Änderungen an einer Feldzeile — wie [_zuordnung] je Klick frisch
  /// gebaut.
  FeldAenderungen get _aenderungen =>
      FeldAenderungen(bearbeitung: _bearbeitung, onGeaendert: _neuAufbauen);

  void _neuAufbauen() => setState(() {});

  void _feldHinzufuegen({String? name, bool pflicht = false}) => setState(
    () => _bearbeitung.feldHinzufuegen(name: name, pflicht: pflicht),
  );

  void _alleUebernehmen(List<String> platzhalter) =>
      setState(() => _bearbeitung.alleUebernehmen(platzhalter));

  void _verschiebe(int alterIndex, int neuerIndex) =>
      setState(() => _bearbeitung.verschiebe(alterIndex, neuerIndex));

  /// Klick auf einen offenen Chip: Statt blind ein Feld anzulegen, fragt der
  /// `ZuordnungsDialog` erst, ob ein vorhandenes gemeint ist (#36) —
  /// `{{Verkehrsunfalldatum}}` neben einem Feld `Unfalldatum` ergäbe sonst ein
  /// zweites Feld, das der Anwalt zusätzlich tippt und das doch ins Leere geht.
  Future<void> _addFieldFromPlaceholder(String placeholder) =>
      _zuordnung.vomPlatzhalter(
        context,
        placeholder,
        onNeuesFeld: () => _feldHinzufuegen(name: placeholder),
      );

  /// Klick auf das Kennzeichen „in keiner Datei" einer Feldzeile — derselbe
  /// Dialog aus der anderen Richtung.
  Future<void> _feldZuordnen(int index) =>
      _zuordnung.vomFeld(context, _bearbeitung.fields[index]);

  /// Der eine Weg zu einer Word-Datei — aus der Slot-Karte **und** aus dem
  /// Leerzustand einer neuen Vorlage. Dateidialog und Hineinholen-Angebot (#33)
  /// stehen in [VorlagenDateiwahl]; hier bleibt, was danach am Stand passiert.
  Future<void> _pickFile(TemplateFileSlot slot) async {
    final pfad = await VorlagenDateiwahl.waehle(context);
    if (pfad == null || !mounted) {
      return;
    }
    setState(() {
      _bearbeitung.setzePfad(slot, pfad);
      // Der Vorlagenname aus dem Dateinamen — nur in ein leeres Feld, und
      // sichtbar als Vorschlag (§1.3). Bei jeder Wahl, nicht nur der ersten:
      // Wer die Datei tauscht, bevor er etwas getippt hat, soll den Namen der
      // neuen Datei bekommen.
      _bearbeitung.nameVorschlagen(pfad);
    });
    context.read<TemplatePlaceholdersBloc>().add(
      LoadTemplatePlaceholders(pfad, slot),
    );
  }

  void _removeFile(TemplateFileSlot slot) {
    setState(() => _bearbeitung.setzePfad(slot, null));
    context.read<TemplatePlaceholdersBloc>().add(
      ClearTemplatePlaceholders(slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: PlatzhalterFehlerMelder(
        // Der Ablauf „Datei zuerst": Was auf ein fertig gelesenes Dokument
        // folgt, entscheidet [EinleseReaktion] — Felder anlegen, nach einem
        // Wechsel abgleichen. Hier steht nur der Horcher.
        child: BlocListener<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
          listener: (context, zustand) =>
              _reaktion.verarbeite(context, _bearbeitung, zustand),
          child: BlocConsumer<FormTemplateDataBloc, FormTemplateDataState>(
            listener: (context, state) {
              if (state is FormTemplateDataSuccess) {
                // `pop` statt `maybePop`: Der Pop selbst soll die Wache
                // übergehen. Gespeichert ist gespeichert — nach dem Erfolg gibt
                // es nichts mehr zu verwerfen, und eine Rückfrage stünde dem
                // Anwalt nur im Weg. `true` heißt „es hat sich etwas geändert"
                // und lässt die Übersicht neu laden.
                Navigator.of(context).pop(true);
              } else if (state is FormTemplateDataError) {
                Rueckmeldung.zeigeFehler(context, state.message);
              }
            },
            builder: (context, state) {
              // Die Wache sitzt **innerhalb** des Consumers, weil sie den
              // Schreibzustand kennen muss: Solange geschrieben wird, darf
              // nichts aufgehen, was der Erfolgs-Pop oben sonst statt der Seite
              // träfe (siehe `VorlagenVerlassenWache.gesperrt`).
              return VorlagenVerlassenWache(
                bearbeitung: _bearbeitung,
                gesperrt: state is SubmittingFormTemplateData,
                child: ReactiveForm(
                  formGroup: _bearbeitung.formGroup,
                  // Wo die Bausteine stehen und wer scrollt, entscheidet allein
                  // `VorlagenEditorLayout` (#104 Stufe 3a). Hier bleibt die
                  // Verdrahtung: welcher Baustein welchen Teil des Stands
                  // bekommt und welche Handlung er auslöst.
                  child: VorlagenEditorLayout(
                    kopf: VorlagenEditorKopf(bearbeiten: isEditing),
                    // Die Knöpfe stehen oben im Kopf, nicht mehr unter der
                    // Feldertabelle. Über `maybePop`, damit die Wache
                    // dazwischengeht: ohne Änderungen ist die Seite sofort weg,
                    // mit Änderungen fragt sie erst. Und `false` statt des
                    // früheren `true` — Abbrechen hat nichts geändert, die
                    // Übersicht musste bisher grundlos neu laden.
                    knopfzeile: FormTemplateActionButtons(
                      onCancel: () => Navigator.of(context).maybePop(false),
                      fields: _bearbeitung.fields,
                      existingItemId: widget.formTemplate?.id,
                      wordFilePathOhneAuflistung:
                          _bearbeitung.pfadOhneAuflistung,
                      wordFilePathMitAuflistung: _bearbeitung.pfadMitAuflistung,
                      nurAbbrechen: _bearbeitung.zeigtLeerzustand,
                    ),
                    // Solange der Name noch der Vorschlag aus dem Dateinamen
                    // ist, sagt die Karte das darunter. Der
                    // `ReactiveFormConsumer` ist der Grund, warum der Hinweis
                    // beim ersten getippten Zeichen verschwindet: Tippen ändert
                    // nur die FormGroup, nicht den Zustand der Seite.
                    namensKarte: ReactiveFormConsumer(
                      builder: (context, _, _) => TemplateNameCard(
                        hinweis: _bearbeitung.nameZeigtVorschlag
                            ? 'Vorschlag aus ${_bearbeitung.nameVorschlagQuelle}'
                                  ' — bei Bedarf anpassen'
                            : null,
                      ),
                    ),
                    // Neue Vorlage, noch keine Datei: Statt eines leeren
                    // Formulars steht die eine Frage da, mit der alles anfängt.
                    leerzustand: _bearbeitung.zeigtLeerzustand
                        ? VorlagenLeerzustand(onDateiWaehlen: _pickFile)
                        : null,
                    linkeSpalte: [
                      TemplateFileSlots(
                        bearbeitung: _bearbeitung,
                        onPick: _pickFile,
                        onRemove: _removeFile,
                      ),

                      // Unter den Dateien: Was der Vorlage fehlt, steht an
                      // **einer** Stelle statt als Zählzeile je Datei (#104).
                      VorlagenStandBereich(
                        bearbeitung: _bearbeitung,
                        onAlleUebernehmen: _alleUebernehmen,
                      ),

                      // Die Chips — zugeklappt, weil Nachschlagen. Der
                      // ReactiveFormConsumer trägt die aktuell eingetragenen
                      // Feldnamen hinein (Chip-Optik „übernommen"): Sie leben in
                      // den Controls, und Tippen baut die Seite nicht neu auf.
                      ReactiveFormConsumer(
                        builder: (context, _, _) => PlatzhalterAbschnitt(
                          vorhandeneNamen: _bearbeitung.feldnamen,
                          onPlaceholderSelected: _addFieldFromPlaceholder,
                        ),
                      ),

                      // Direkt unter den Chips: Dort steht der Anwalt vor einem
                      // Platzhalter, den er nicht anklicken kann, und fragt sich,
                      // warum (#31).
                      const AppEigenePlatzhalterListe(),
                    ],
                    felder: _felderKarte,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Die Feldertabelle. Derselbe Weg wie [VorlagenStandBereich]: Der Stand
  /// hängt vom `TemplatePlaceholdersBloc` UND vom Formular ab — Umbenennen
  /// (Tippen, Zuordnungsdialog) läuft nur über die FormGroup, ohne setState
  /// der Seite. Ohne den `ReactiveFormConsumer` hinkten Filter und Zähler der
  /// Karte jeder Umbenennung hinterher.
  Widget _felderKarte(BuildContext context, bool eigenerScrollbereich) {
    return BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      builder: (context, zustand) => ReactiveFormConsumer(
        builder: (context, _, _) => TemplateFieldsCard(
          fields: _bearbeitung.fields,
          formGroup: _bearbeitung.formGroup,
          onAddField: _feldHinzufuegen,
          onReorder: _verschiebe,
          onTypeChanged: _aenderungen.typ,
          onDatenquelleChanged: _aenderungen.datenquelle,
          onRequiredChanged: _aenderungen.pflicht,
          onVorbelegungChanged: _aenderungen.vorbelegung,
          onDelete: _aenderungen.loeschen,
          onZuordnen: _feldZuordnen,
          stand: _bearbeitung.stand(zustand),
          feldname: _bearbeitung.feldname,
          eigenerScrollbereich: eigenerScrollbereich,
        ),
      ),
    );
  }
}
