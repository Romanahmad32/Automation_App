import 'package:material_ui/material_ui.dart';

/// Eine ruhige Zeile mit Symbol und Satz: Symbol 20, Abstand 10, `bodyMedium`.
///
/// Für Aussagen, die neben dem Eigentlichen stehen — „Ihre Daten bleiben
/// erhalten“, „Meist fehlt nur kurz die Internetverbindung“. Bewusst kein
/// Kasten und kein Rot: Sie soll beruhigen, nicht alarmieren. Für einen
/// Fehler, der eine Handlung verlangt, gibt es `FehlerHinweis`.
///
/// Stand zuerst privat in `AnwendungsInfo`; der Dialog „App aktualisieren“
/// (#196) braucht dieselbe Zeile.
class HinweisZeile extends StatelessWidget {
  const HinweisZeile({
    required this.symbol,
    required this.text,
    this.farbe,
    this.textfarbe,
    super.key,
  });

  final IconData symbol;
  final String text;

  /// Farbe von Symbol und Text; ohne Angabe `onSurfaceVariant`.
  final Color? farbe;

  /// Eigene Textfarbe, wenn nur das Symbol die [farbe] tragen soll — etwa
  /// ein Hinweis in der Tertiärfarbe, dessen Satz lesbar dunkel bleibt.
  final Color? textfarbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbton = farbe ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(symbol, size: 20, color: farbton),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textfarbe ?? farbton,
            ),
          ),
        ),
      ],
    );
  }
}
