import 'package:flutter/material.dart';

/// Die beiden Text-Controller einer Zeile der Schadensaufstellung
/// (Bezeichnung und Betrag), zusammengefasst, damit sie gemeinsam angelegt
/// und gemeinsam freigegeben werden.
class DamageItemControllers {
  DamageItemControllers({String? description, String? amount})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);

  final TextEditingController description;
  final TextEditingController amount;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}
