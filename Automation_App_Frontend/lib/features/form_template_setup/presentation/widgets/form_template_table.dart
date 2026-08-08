import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_row.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_table_layout.dart';
import 'package:flutter/material.dart';

/// Flex-basierte Tabelle mit sortierbaren Spaltenkoepfen. Bewusst kein
/// [DataTable]: dessen Spalten lassen sich nicht flexibel auf die volle Breite
/// verteilen (und der Sortierpfeil schiebt Spalten aus dem Bild). Die Sortierung
/// ist lokaler Widget-State und liegt nicht im geteilten Singleton-Bloc.
class FormTemplateTable extends StatefulWidget {
  final List<FormTemplate> templates;

  const FormTemplateTable({super.key, required this.templates});

  @override
  State<FormTemplateTable> createState() => _FormTemplateTableState();
}

class _FormTemplateTableState extends State<FormTemplateTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  List<FormTemplate> get _sortedTemplates {
    final list = [...widget.templates];
    final index = _sortColumnIndex;
    if (index == null) return list;

    int compare(FormTemplate a, FormTemplate b) {
      switch (index) {
        case colName:
          return a.templateName.toLowerCase().compareTo(
            b.templateName.toLowerCase(),
          );
        case colFiles:
          return fileCount(a).compareTo(fileCount(b));
        case colFields:
          return a.fields.length.compareTo(b.fields.length);
        default:
          return 0;
      }
    }

    list.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _sortedTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
            itemBuilder: (context, index) =>
                FormTemplateRow(template: sorted[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        _headerCell('Vorlage', colName, style, flex: flexName),
        _headerCell('Dateien', colFiles, style, flex: flexFiles),
        _headerCell('Felder', colFields, style, flex: flexFields),
        // Aktionen ist nicht sortierbar.
        SizedBox(
          width: actionsWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text('Aktionen', style: style, textAlign: TextAlign.end),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(
    String label,
    int columnIndex,
    TextStyle? style, {
    required int flex,
  }) {
    final active = _sortColumnIndex == columnIndex;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                active
                    ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 16,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
