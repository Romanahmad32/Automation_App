import 'package:flutter/material.dart';

/// Ein beschriftetes Textfeld im Bearbeiten-Dialog — eigenständig, damit kein
/// privates Hilfs-Widget nötig ist und es wiederverwendbar bleibt.
class VorgangDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  /// Beanstandung am Feld; `null` heißt: keine. Der Dialog prüft erst beim
  /// Speichern, die Meldung entsteht also nicht beim Tippen.
  final String? errorText;

  const VorgangDialogField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
