import 'package:flutter/material.dart';

/// Sagt, dass eine gelesene Signatur noch **aussteht** — und was daran erst
/// beim Speichern dazukommt (§4.7, ergänzt am 02.09.2026).
///
/// Ohne diese Zeile sähe der Import aus wie erledigt: Das Feld ist gefüllt, die
/// Vorschau zeigt Schrift und Farben — nur das Logo fehlt, weil die Bilder erst
/// bei der Übernahme im Dienst landen. Ein fehlendes Logo ohne Erklärung liest
/// sich wie ein Fehler.
class SignaturVorgemerktZeile extends StatelessWidget {
  final String name;

  /// Ob die gelesene Fassung überhaupt Bilder hat; ohne sie fehlt in der
  /// Vorschau nichts und der Satz dazu wäre eine Verwirrung.
  final bool mitBildern;

  const SignaturVorgemerktZeile({
    super.key,
    required this.name,
    this.mitBildern = false,
  });

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
            text(name, mitBildern: mitBildern),
            style: theme.textTheme.bodySmall?.copyWith(color: ton),
          ),
        ),
      ],
    );
  }

  /// Der Satz selbst. Öffentlich, weil ein Test darauf zeigt: Er ist die ganze
  /// Auskunft darüber, dass noch nichts geschrieben ist.
  static String text(String name, {required bool mitBildern}) {
    final grundstock =
        'Aus Outlook gelesen: „$name". Gespeichert wird sie erst mit '
        '„Speichern" — bis dahin bleibt die bisherige Signatur in Kraft.';
    return mitBildern
        ? '$grundstock Die Bilder kommen dabei dazu; deshalb fehlen sie in der '
              'Vorschau noch.'
        : grundstock;
  }
}
