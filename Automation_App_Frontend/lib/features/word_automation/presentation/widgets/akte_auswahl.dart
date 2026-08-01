import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_constants.dart';
import 'package:flutter/material.dart';

/// Auswahl des Akten-Ordners des Mandanten: Dropdown über vorhandene Ordner
/// (plus „Neue Akte anlegen …") und/oder ein Textfeld für einen neuen Ordner.
/// Zustandslos — Änderungen meldet es über [onDropdownChanged] (Dropdown-Wert
/// oder [neuSentinel]) und [onNeueAkteTextChanged] zurück.
class AkteAuswahl extends StatelessWidget {
  final Mandant mandant;
  final bool neueAkte;
  final String? gewaehlteAkte;
  final TextEditingController neueAkteController;
  final void Function(String? value) onDropdownChanged;
  final VoidCallback onNeueAkteTextChanged;

  const AkteAuswahl({
    super.key,
    required this.mandant,
    required this.neueAkte,
    required this.gewaehlteAkte,
    required this.neueAkteController,
    required this.onDropdownChanged,
    required this.onNeueAkteTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ordner = mandant.aktenOrdnernamen;
    final children = <Widget>[];

    if (ordner.isNotEmpty) {
      children.add(
        SearchableDropdown<String>(
          value: neueAkte ? neuSentinel : gewaehlteAkte,
          labelText: 'Akte (Ordner des Mandanten)',
          hintText: 'Akte suchen oder auswählen',
          leadingIcon: const Icon(Icons.folder_outlined),
          entries: [
            for (final o in ordner) SearchableDropdownEntry(value: o, label: o),
            const SearchableDropdownEntry(
              value: neuSentinel,
              label: '＋ Neue Akte anlegen …',
            ),
          ],
          onChanged: onDropdownChanged,
        ),
      );
    }

    if (neueAkte || ordner.isEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(
        TextField(
          controller: neueAkteController,
          onChanged: (_) => onNeueAkteTextChanged(),
          decoration: const InputDecoration(
            labelText: 'Neuer Akten-Ordner',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.create_new_folder_outlined),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
