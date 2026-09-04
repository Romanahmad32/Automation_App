import 'package:flutter/material.dart';

/// Sagt, dass eine gelesene Signatur noch **aussteht** (§4.7, ergänzt am
/// 02.09.2026).
///
/// Ohne diese Zeile sähe der Import aus wie erledigt: Das Feld ist gefüllt, die
/// Vorschau zeigt die neue Signatur — geschrieben ist aber nichts, und unter
/// den Mails steht bis zum Speichern weiter die bisherige.
///
/// **Der Zusatz über fehlende Bilder ist weg** (04.09.2026). Er stand hier,
/// weil die Vorschau die Bilder erst nach der Übernahme zeigen konnte. Das
/// stimmte nicht einmal: Sie holte sie aus der Ablage und bekam dort unter
/// demselben Namen das Logo der **vorigen** Signatur. Seit sie in Outlooks
/// Beiordner liest, zeigt sie das richtige, und es fehlt nichts mehr zu
/// erklären.
class SignaturVorgemerktZeile extends StatelessWidget {
  final String name;

  const SignaturVorgemerktZeile({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ton = theme.colorScheme.tertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(Icons.pending_outlined, size: 16, color: ton),
        Expanded(
          child: Text(
            text(name),
            style: theme.textTheme.bodySmall?.copyWith(color: ton),
          ),
        ),
      ],
    );
  }

  /// Der Satz selbst. Öffentlich, weil ein Test darauf zeigt: Er ist die ganze
  /// Auskunft darüber, dass noch nichts geschrieben ist.
  static String text(String name) =>
      'Aus Outlook gelesen: „$name". Gespeichert wird sie erst mit '
      '„Speichern" — bis dahin bleibt die bisherige Signatur in Kraft.';
}
