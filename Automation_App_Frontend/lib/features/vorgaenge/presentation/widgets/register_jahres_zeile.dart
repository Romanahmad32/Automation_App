import 'package:flutter/material.dart';

/// Die fett gesetzte Jahresüberschrift, die in der Registertabelle vor jedem
/// Jahrgang steht — genau wie im Registerbuch der Kanzlei und in der
/// Word-/PDF-Fassung (`RegisterDokument` im Backend setzt dieselbe Zeile).
///
/// Vierstellig, auch wenn das Zeichen daneben nur „01/19" sagt: Der Anwalt
/// blättert in Jahrgängen, und „19" ist als Überschrift keine Jahreszahl.
class RegisterJahresZeile extends StatelessWidget {
  final String jahr;

  const RegisterJahresZeile({super.key, required this.jahr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      jahr,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
