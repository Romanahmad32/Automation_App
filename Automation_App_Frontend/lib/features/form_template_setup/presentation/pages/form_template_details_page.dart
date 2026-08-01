import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/initial_template_form.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slot_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_name_card.dart';
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

  // Zuletzt je Slot angezeigte Fehlermeldung, um Snackbar-Wiederholungen
  // bei jedem Rebuild zu vermeiden.
  final Map<TemplateFileSlot, String?> _lastErrorShown = {};

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

  void _addNewField({String? initialLabel}) {
    setState(() {
      final fieldKey = 'field_${_nextFieldIndex++}';
      formGroup.addAll({
        fieldKey: FormControl<String>(
          value: initialLabel,
          validators: [Validators.required],
        ),
      });
      fields.add(
        FieldData(
          order: fields.length,
          label: fieldKey,
          required: false,
          inputType: InputType.text,
        ),
      );
    });
  }

  /// Übernimmt einen erkannten Platzhalter als Eingabefeld — außer es gibt
  /// bereits ein Feld mit demselben Namen.
  void _addFieldFromPlaceholder(String placeholder) {
    final alreadyExists = fields.any((field) {
      final label = formGroup
          .control(field.label)
          .value as String?;
      return label?.trim().toLowerCase() == placeholder.toLowerCase();
    });
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Das Feld "$placeholder" existiert bereits.')),
      );
      return;
    }
    _addNewField(initialLabel: placeholder);
  }

  Future<void> _pickFile(TemplateFileSlot slot) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null || !mounted) {
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

  void _onTypeChanged(int i, InputType? v) =>
      setState(() => fields[i] = fields[i].copyWith(inputType: v));

  void _onDatenquelleChanged(int i, FeldDatenquelle? v) =>
      setState(() => fields[i] = fields[i].copyWith(datenquelle: v));

  void _onRequiredChanged(int i, bool? v) =>
      setState(() => fields[i] = fields[i].copyWith(required: v ?? false));

  void _onDeleteField(int i) => setState(() {
    formGroup.removeControl(fields[i].label);
    fields.removeAt(i);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      // Fehler beim Lesen der Word-Datei (z. B. Datei in Word geöffnet) auch
      // als Snackbar melden, nicht nur als Inline-Text in der Platzhalter-Box.
      body: BlocListener<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
        listener: (context, state) {
          for (final slot in TemplateFileSlot.values) {
            final result = state.forSlot(slot);
            final message = result is SlotPlaceholdersError
                ? result.message
                : null;
            if (message != null && _lastErrorShown[slot] != message) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
            _lastErrorShown[slot] = message;
          }
        },
        child: BlocConsumer<FormTemplateDataBloc, FormTemplateDataState>(
          listener: (context, state) {
            if (state is FormTemplateDataSuccess) {
              context.router.maybePop(true);
            } else if (state is FormTemplateDataError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
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

                    TemplateFileSlotCard(
                      slot: TemplateFileSlot.ohneAuflistung,
                      path: _wordFilePathOhne,
                      title: 'Vorlage ohne Auflistung (HGN)',
                      subtitle:
                          'Standardbrief mit Haftung dem Grunde nach – ohne '
                          'Schadensaufstellung.',
                      onPick: () => _pickFile(TemplateFileSlot.ohneAuflistung),
                      onRemove: () =>
                          _removeFile(TemplateFileSlot.ohneAuflistung),
                      onPlaceholderSelected: _addFieldFromPlaceholder,
                    ),

                    TemplateFileSlotCard(
                      slot: TemplateFileSlot.mitAuflistung,
                      path: _wordFilePathMit,
                      title: 'Vorlage mit Auflistung (Schadensaufstellung)',
                      subtitle:
                          'Enthält {{Schadensaufstellung}}; beim Ausfüllen wird '
                          'ein zusätzlicher Schritt für die Schadenspositionen '
                          'und die RVG-Kostenberechnung angezeigt.',
                      onPick: () => _pickFile(TemplateFileSlot.mitAuflistung),
                      onRemove: () => _removeFile(TemplateFileSlot.mitAuflistung),
                      onPlaceholderSelected: _addFieldFromPlaceholder,
                    ),

                    TemplateFieldsCard(
                      fields: fields,
                      formGroup: formGroup,
                      onAddField: _addNewField,
                      onReorder: _reorderFields,
                      onTypeChanged: _onTypeChanged,
                      onDatenquelleChanged: _onDatenquelleChanged,
                      onRequiredChanged: _onRequiredChanged,
                      onDelete: _onDeleteField,
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
