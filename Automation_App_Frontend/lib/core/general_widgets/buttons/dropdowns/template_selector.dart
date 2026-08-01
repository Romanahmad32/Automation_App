import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/form_template_setup/domain/entities/form_template.dart';
import '../../../../features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';

/// Durchsuchbares Auswahlfeld für eine Formularvorlage, im Look der übrigen
/// Formularfelder (OutlineInputBorder + Label). Tippen filtert die Liste
/// live nach dem Vorlagennamen.
///
/// Die Auswahl wird über die Vorlagen-ID mit der Liste des
/// [FormTemplateOverviewBloc] abgeglichen: Wird die gewählte Vorlage
/// andernorts bearbeitet oder gelöscht, meldet [onChanged] die
/// aktualisierte Instanz bzw. `null`.
class TemplateSelector extends StatefulWidget {
  final FormTemplate? value;
  final ValueChanged<FormTemplate?> onChanged;
  final String labelText;
  final String hintText;

  const TemplateSelector({
    super.key,
    this.value,
    required this.onChanged,
    this.labelText = 'Formularvorlage',
    this.hintText = 'Vorlage suchen oder auswählen',
  });

  @override
  State<TemplateSelector> createState() => _TemplateSelectorState();
}

class _TemplateSelectorState extends State<TemplateSelector> {
  /// Zuletzt geladene Liste, damit das Feld während eines Neuladens
  /// nicht kurz durch einen Spinner ersetzt wird.
  List<FormTemplate>? _templates;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<FormTemplateOverviewBloc>();
    final state = bloc.state;
    if (state is FormTemplateOverviewLoaded) {
      _templates = state.formTemplates;
    } else {
      bloc.add(LoadFormTemplatesEvent());
    }
    _controller.text = widget.value?.templateName ?? '';
    // Verlässt der Fokus das Feld ohne Auswahl, bliebe sonst der getippte
    // Filtertext stehen; stattdessen den Namen der Auswahl wiederherstellen.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _syncControllerToValue();
      }
    });
  }

  @override
  void didUpdateWidget(TemplateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value?.id != widget.value?.id ||
        oldWidget.value?.templateName != widget.value?.templateName) {
      _syncControllerToValue();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Feldtext auf den Namen der aktuellen Auswahl setzen — aber nicht
  /// mitten ins Tippen hinein, solange das Feld den Fokus hat.
  void _syncControllerToValue() {
    if (_focusNode.hasFocus) {
      return;
    }
    final name = widget.value?.templateName ?? '';
    if (_controller.text != name) {
      _controller.text = name;
    }
  }

  FormTemplate? _findById(List<FormTemplate>? templates, int? id) {
    if (templates == null || id == null) {
      return null;
    }
    for (final template in templates) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FormTemplateOverviewBloc, FormTemplateOverviewState>(
      listener: (context, state) {
        if (state is! FormTemplateOverviewLoaded) {
          return;
        }
        _templates = state.formTemplates;
        // Gewählte Vorlage mit der frischen Liste abgleichen.
        final current = widget.value;
        if (current == null) {
          return;
        }
        final updated = _findById(state.formTemplates, current.id);
        if (updated != current) {
          widget.onChanged(updated);
        }
      },
      builder: (context, state) {
        final templates = state is FormTemplateOverviewLoaded
            ? state.formTemplates
            : _templates;
        final isLoading = state is FormTemplateOverviewLoading;

        if (templates == null) {
          if (state is FormTemplateOverviewError) {
            return _ErrorHint(message: state.message);
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final selected = _findById(templates, widget.value?.id);

        return DropdownMenu<int>(
          controller: _controller,
          focusNode: _focusNode,
          initialSelection: selected?.id,
          enableFilter: true,
          requestFocusOnTap: true,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 320,
          label: Text(widget.labelText),
          hintText: widget.hintText,
          trailingIcon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          dropdownMenuEntries: templates
              .map(
                (template) => DropdownMenuEntry<int>(
                  value: template.id,
                  label: template.templateName,
                ),
              )
              .toList(),
          onSelected: (id) {
            widget.onChanged(_findById(templates, id));
            // Filter-Fokus abgeben, damit das Feld den gewählten Namen
            // anzeigt und die nächste Öffnung ungefiltert startet.
            _focusNode.unfocus();
          },
        );
      },
    );
  }
}

class _ErrorHint extends StatelessWidget {
  final String message;

  const _ErrorHint({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.error_outline, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Vorlagen konnten nicht geladen werden: $message',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
