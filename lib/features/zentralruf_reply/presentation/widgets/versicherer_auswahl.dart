import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Auswahl eines Versicherers aus der Wissensbasis (aus früheren
/// Zentralruf-Antworten gelernt). Wird bei Negativ-Antworten angeboten, damit
/// der Anwalt den Versicherer nicht komplett abtippen muss, wenn er ihn auf
/// anderem Weg ermittelt hat. Ist das Register leer, zeigt das Widget nichts an.
class VersichererAuswahl extends StatelessWidget {
  /// Id des aktuell gewählten Versicherers, falls schon einer gewählt wurde.
  final int? value;

  /// Meldet den gewählten Registereintrag an das Elternformular (das damit die
  /// Versicherer-Felder befüllt).
  final ValueChanged<Versicherer> onGewaehlt;

  const VersichererAuswahl({
    super.key,
    required this.value,
    required this.onGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersichererCubit, List<Versicherer>>(
      bloc: getIt<VersichererCubit>(),
      builder: (context, versicherer) {
        if (versicherer.isEmpty) return const SizedBox.shrink();
        return SearchableDropdown<int>(
          value: value,
          labelText: 'Versicherer aus früheren Antworten wählen',
          hintText: 'Versicherer suchen oder auswählen',
          helperText:
              'Füllt die Versicherer-Felder mit den zuletzt bekannten Daten.',
          helperMaxLines: 2,
          leadingIcon: const Icon(Icons.apartment),
          entries: [
            for (final eintrag in versicherer)
              SearchableDropdownEntry<int>(
                value: eintrag.id,
                label: _label(eintrag),
              ),
          ],
          onChanged: (id) {
            final gewaehlt = versicherer.where((v) => v.id == id).firstOrNull;
            if (gewaehlt != null) onGewaehlt(gewaehlt);
          },
        );
      },
    );
  }

  String _label(Versicherer eintrag) {
    final ort = (eintrag.ort ?? '').trim();
    return ort.isEmpty ? eintrag.name : '${eintrag.name} · $ort';
  }
}
