import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Suche und Ausschnitt über den Zeilen des Berichts. Dieselbe Aufteilung wie
/// im Zuordnungsstapel — bei viertausend Zeilen ist die Liste ohne Filter kein
/// Werkzeug, sondern nur lang.
class ImportFilterLeiste extends StatelessWidget {
  final ImportFilter filter;
  final Map<ImportSicht, int> zaehler;

  const ImportFilterLeiste({
    super.key,
    required this.filter,
    required this.zaehler,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MandantenImportCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        EntitySearchBar(
          initialQuery: filter.query,
          hintText: 'Nach Name oder Ordnername suchen …',
          onChanged: (wert) => cubit.filtern(filter.copyWith(query: wert)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sicht in ImportSicht.values)
              if (zeigt(sicht))
                FilterChip(
                  selected: filter.sicht == sicht,
                  onSelected: (_) =>
                      cubit.filtern(filter.copyWith(sicht: sicht)),
                  label: Text('${sicht.bezeichnung} (${zaehler[sicht] ?? 0})'),
                ),
          ],
        ),
      ],
    );
  }

  /// „Ordner unbekannt" erscheint nur, wenn es solche Zeilen gibt — im
  /// Normalfall ist es kein Ausschnitt, den man wählen möchte, sondern ein
  /// Alarm. Ein Umschalter mit `(0)`, der in neunundneunzig von hundert Fällen
  /// dasteht, macht die Leiste länger und sagt nichts.
  bool zeigt(ImportSicht sicht) =>
      sicht != ImportSicht.unbekannterOrdner ||
      filter.sicht == sicht ||
      (zaehler[sicht] ?? 0) > 0;
}
