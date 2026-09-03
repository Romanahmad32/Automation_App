import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Schmales Eingabefeld für eine Ganzzahl — vier davon stehen im
/// `DatumsVorbelegungEditor` nebeneinander (Jahre, Monate, Wochen, Tage).
///
/// Bewusst **kein** `GeneralTextField`: das arbeitet auf einem
/// reactive_forms-Control, die Vorbelegung hängt aber an `FieldData` und nicht
/// am Formular der Detailseite. Ein eigenes Control dafür anzulegen hiesse,
/// den Feldnamen-Schlüssel der Seite (`field_0`, …) mit fremden Einträgen zu
/// mischen — die Seite tauscht ihn beim Speichern zurück.
///
/// Leer heisst 0; der Aufrufer liest den Text und parst ihn selbst, damit ein
/// geleertes Feld nicht gleich wieder mit „0" gefüllt wird.
class GanzzahlFeldKlein extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String> onChanged;

  const GanzzahlFeldKlein({
    super.key,
    required this.controller,
    required this.labelText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
