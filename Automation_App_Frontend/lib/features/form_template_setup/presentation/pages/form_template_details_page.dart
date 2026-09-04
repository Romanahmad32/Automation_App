import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:file_picker/file_picker.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/app_eigene_platzhalter_liste.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_aenderungen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/initial_template_form.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_fehler_melder.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slots.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_name_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/zuordnungs_aktionen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/zuordnungs_dialog.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_hineinholen_angebot.dart';
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
  List<FieldData> fields = [];
  late FormGroup formGroup;
  String? _wordFilePathOhne;
  String? _wordFilePathMit;
  int _nextFieldIndex = 0;

  // Helper getter to determine the current mode
  bool get isEditing => widget.formTemplate != null;

  @override
  void initState() {
    super.initState();
    _wordFilePathOhne = widget.formTemplate?.wordFilePathOhneAuflistung;
    _wordFilePathMit = widget.formTemplate?.wordFilePathMitAuflistung;

    final initial = InitialTemplateForm.fromTemplate(widget.formTemplate);
    formGroup = initial.formGroup;
    fields.addAll(initial.fields);
    _nextFieldIndex = initial.nextFieldIndex;

    // Bei bereits verknüpften Word-Dateien die Platzhalter direkt laden.
    if (_wordFilePathOhne != null) {
      context.read<TemplatePlaceholdersBloc>().add(
        LoadTemplatePlaceholders(
          _wordFilePathOhne!,
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    }
    if (_wordFilePathMit != null) {
      context.read<TemplatePlaceholdersBloc>().add(
        LoadTemplatePlaceholders(
          _wordFilePathMit!,
          TemplateFileSlot.mitAuflistung,
        ),
      );
    }
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final field = fields.removeAt(oldIndex);
      fields.insert(newIndex, field);
    });
  }

  void _addNewField({String? initialLabel, bool required = false}) {
    setState(() {
      final fieldKey = 'field_${_nextFieldIndex++}';
      formGroup.addAll({
        fieldKey: FormControl<String>(
          value: initialLabel,
          validators: [Validators.required],
        ),
      });
      // Feldtyp und Datenquelle aus dem Platzhalternamen vorschlagen — sichtbar
      // im Dropdown und änderbar, nichts wird stillschweigend gebunden (§1.3).
      fields.add(
        FeldDatenquelleErkennung.neuesFeld(
          order: fields.length,
          controlKey: fieldKey,
          platzhalter: initialLabel,
          required: required,
        ),
      );
    });
  }

  /// „Alle übernehmen" (#35 Teil 3): Die Chips liefern bereits nur, was
  /// übernehmbar ist ([PlatzhalterUebernahme.uebernehmbare]). Die Felder
  /// entstehen als Pflichtfelder — gefahrlos, weil die Pflicht beim Ausfüllen
  /// je gewählter Word-Datei abgeleitet wird (Teil 2) und ein Feld ohne
  /// Platzhalter dort nichts sperrt.
  void _alleUebernehmen(List<String> placeholders) {
    for (final placeholder in placeholders) {
      _addNewField(initialLabel: placeholder, required: true);
    }
  }

  /// Beide Wege der Zuordnung (#36) — sie arbeiten auf dem aktuellen Stand von
  /// [fields] und [formGroup] und werden deshalb je Klick frisch gebaut.
  ZuordnungsAktionen get _zuordnung => ZuordnungsAktionen.ausZustand(
    context.read<TemplatePlaceholdersBloc>().state,
    fields: fields,
    formGroup: formGroup,
  );

  /// Klick auf einen offenen Chip: Statt blind ein Feld anzulegen, fragt der
  /// [ZuordnungsDialog] erst, ob ein vorhandenes gemeint ist (#36) —
  /// `{{Verkehrsunfalldatum}}` neben einem Feld `Unfalldatum` ergäbe sonst ein
  /// zweites Feld, das der Anwalt zusätzlich tippt und das doch ins Leere geht.
  Future<void> _addFieldFromPlaceholder(String placeholder) {
    return _zuordnung.vomPlatzhalter(
      context,
      placeholder,
      onNeuesFeld: () => _addNewField(initialLabel: placeholder),
    );
  }

  /// Klick auf das Kennzeichen „in keiner Datei" einer Feldzeile — derselbe
  /// Dialog aus der anderen Richtung.
  Future<void> _feldZuordnen(int index) =>
      _zuordnung.vomFeld(context, fields[index]);

  Future<void> _pickFile(TemplateFileSlot slot) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    var path = result?.files.firstOrNull?.path;
    if (path == null || !mounted) {
      return;
    }
    // Außerhalb des Vorlagenordners gewählte Dateien hineinholen (#33).
    path = await VorlagenHineinholenAngebot.bieteAn(context, path);
    if (!mounted) {
      return;
    }
    setState(() {
      if (slot == TemplateFileSlot.ohneAuflistung) {
        _wordFilePathOhne = path;
      } else {
        _wordFilePathMit = path;
      }
    });
    context.read<TemplatePlaceholdersBloc>().add(
      LoadTemplatePlaceholders(path, slot),
    );
  }

  void _removeFile(TemplateFileSlot slot) {
    setState(() {
      if (slot == TemplateFileSlot.ohneAuflistung) {
        _wordFilePathOhne = null;
      } else {
        _wordFilePathMit = null;
      }
    });
    context.read<TemplatePlaceholdersBloc>().add(
      ClearTemplatePlaceholders(slot),
    );
  }

  /// Alle Änderungen an einer Feldzeile — wie [_zuordnung] je Klick frisch
  /// gebaut, weil sie auf dem aktuellen Stand von [fields] arbeiten.
  FeldAenderungen get _aenderungen => FeldAenderungen(
    fields: fields,
    formGroup: formGroup,
    onGeaendert: () => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: PlatzhalterFehlerMelder(
        child: BlocConsumer<FormTemplateDataBloc, FormTemplateDataState>(
          listener: (context, state) {
            if (state is FormTemplateDataSuccess) {
              context.router.maybePop(true);
            } else if (state is FormTemplateDataError) {
              Rueckmeldung.zeigeFehler(context, state.message);
            }
          },
          builder: (context, state) {
            return ReactiveForm(
              formGroup: formGroup,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        isEditing
                            ? 'Vorlage bearbeiten'
                            : 'Neue Vorlage erstellen',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const TemplateNameCard(),

                    TemplateFileSlots(
                      pfadOhneAuflistung: _wordFilePathOhne,
                      pfadMitAuflistung: _wordFilePathMit,
                      fields: fields,
                      onPick: _pickFile,
                      onRemove: _removeFile,
                      onPlaceholderSelected: _addFieldFromPlaceholder,
                      onAlleUebernehmen: _alleUebernehmen,
                    ),

                    // Direkt unter den Chips: Dort steht der Anwalt vor einem
                    // Platzhalter, den er nicht anklicken kann, und fragt sich,
                    // warum (#31).
                    const AppEigenePlatzhalterListe(),

                    TemplateFieldsCard(
                      fields: fields,
                      formGroup: formGroup,
                      onAddField: _addNewField,
                      onReorder: _reorderFields,
                      onTypeChanged: _aenderungen.typ,
                      onDatenquelleChanged: _aenderungen.datenquelle,
                      onRequiredChanged: _aenderungen.pflicht,
                      onVorbelegungChanged: _aenderungen.vorbelegung,
                      onDelete: _aenderungen.loeschen,
                      onZuordnen: _feldZuordnen,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FormTemplateActionButtons(
                          onCancel: () => context.router.maybePop(true),
                          fields: fields,
                          existingItemId: widget.formTemplate?.id,
                          wordFilePathOhneAuflistung: _wordFilePathOhne,
                          wordFilePathMitAuflistung: _wordFilePathMit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
