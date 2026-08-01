import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:flutter/material.dart';

/// Editor für die optionalen Kfz-Kennzeichen eines Mandanten (0..n). Zeigt die
/// vorhandenen Kennzeichen als löschbare Chips und bietet ein Eingabefeld zum
/// Hinzufügen weiterer. Kennzeichen werden mit Bindestrich angegeben
/// (z. B. `HG-E 1427`); das Format wird beim Hinzufügen geprüft.
class KennzeichenEditor extends StatefulWidget {
  /// Bereits hinterlegte Kennzeichen (Ausgangswert).
  final List<String> initialKennzeichen;

  /// Wird bei jeder Änderung mit der vollständigen, aktuellen Liste aufgerufen.
  final ValueChanged<List<String>> onChanged;

  const KennzeichenEditor({
    super.key,
    required this.initialKennzeichen,
    required this.onChanged,
  });

  @override
  State<KennzeichenEditor> createState() => _KennzeichenEditorState();
}

class _KennzeichenEditorState extends State<KennzeichenEditor> {
  late final List<String> _kennzeichen = List.of(widget.initialKennzeichen);
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _fehler;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _hinzufuegen() {
    final eingabe = _controller.text.trim();
    if (eingabe.isEmpty) {
      setState(() => _fehler = null);
      return;
    }
    if (!istGueltigesKennzeichen(eingabe)) {
      setState(() => _fehler = kennzeichenHinweis);
      return;
    }
    if (_kennzeichen.any((k) => k.toUpperCase() == eingabe.toUpperCase())) {
      setState(() => _fehler = 'Dieses Kennzeichen ist bereits hinterlegt');
      return;
    }
    setState(() {
      _kennzeichen.add(eingabe);
      _controller.clear();
      _fehler = null;
    });
    widget.onChanged(List.unmodifiable(_kennzeichen));
    _focusNode.requestFocus();
  }

  void _entfernen(String kennzeichen) {
    setState(() => _kennzeichen.remove(kennzeichen));
    widget.onChanged(List.unmodifiable(_kennzeichen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_kennzeichen.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in _kennzeichen)
                  Chip(
                    avatar: const Icon(Icons.directions_car_outlined, size: 18),
                    label: Text(k),
                    onDeleted: () => _entfernen(k),
                    deleteButtonTooltipMessage: 'Kennzeichen entfernen',
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _hinzufuegen(),
                decoration: InputDecoration(
                  labelText: 'Kennzeichen',
                  helperText: kennzeichenHinweis,
                  errorText: _fehler,
                  border:
                      theme.inputDecorationTheme.border ??
                      const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                onPressed: _hinzufuegen,
                icon: const Icon(Icons.add),
                tooltip: 'Kennzeichen hinzufügen',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
