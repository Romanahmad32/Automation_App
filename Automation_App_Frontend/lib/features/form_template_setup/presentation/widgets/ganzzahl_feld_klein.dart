import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kompaktes Eingabefeld für eine Ganzzahl — vier davon stehen im
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
///
/// Die Beschriftung steht als **schwebendes Label** immer oberhalb des
/// Rahmens (`floatingLabelBehavior: always`), statt in den Eingabebereich zu
/// rutschen. Die App-weite `InputDecorationTheme` bemisst ihr Innenpolster für
/// ausgefüllte Formularfelder (16 px auf jeder Seite) — bei der schmalen
/// Feldbreite hier bliebe damit kein Platz für „Monate"/„Wochen", das Label
/// würde abgeschnitten. Deshalb wird das Innenpolster hier bewusst kleiner
/// überschrieben.
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
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Tooltip(
        message: 'Anzahl $labelText',
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            floatingLabelStyle: theme.textTheme.labelSmall,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
