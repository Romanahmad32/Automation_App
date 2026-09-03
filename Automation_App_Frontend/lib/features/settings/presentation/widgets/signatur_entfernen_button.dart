import 'package:flutter/material.dart';

/// Entfernt die Signatur **ganz** — Text, formatierte Fassung und Bilder
/// (§4.7, ergänzt am 02.09.2026).
///
/// **Der Mangel, den das behebt:** Das Signaturfeld zu leeren und zu speichern
/// entfernte nur die Nur-Text-Fassung. Die übernommene HTML-Fassung blieb in
/// den Einstellungen stehen — und weil die Mail sie bevorzugt, ging die
/// Signatur samt Logo **weiter unter jeder Mail hinaus**, obwohl das Feld leer
/// war. In der Vorschau war sie ebenfalls weiter zu sehen, was aussah wie ein
/// Anzeigefehler und keiner war.
///
/// „Formatierung verwerfen" daneben ist etwas anderes und bleibt: Es nimmt
/// Schrift, Farben und Bilder und **behält den Text**. Wer die Signatur
/// loswerden will, braucht beides in einem Schritt.
///
/// Mit Rückfrage, weil nichts davon zurückkommt: Die Bilder liegen danach
/// nicht mehr im Dienst, und aus Outlook geholt werden müsste erneut.
class SignaturEntfernenButton extends StatelessWidget {
  final VoidCallback onEntfernen;
  final bool aktiv;

  const SignaturEntfernenButton({
    super.key,
    required this.onEntfernen,
    this.aktiv = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      onPressed: aktiv ? () => _fragen(context) : null,
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Signatur entfernen'),
      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
    );
  }

  Future<void> _fragen(BuildContext context) async {
    final sicher = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signatur entfernen?'),
        content: const Text(
          'Text, Formatierung und Bilder werden gelöscht. Unter den Mails der '
          'Kanzlei steht danach keine Signatur mehr. Aus Outlook lässt sie '
          'sich jederzeit erneut übernehmen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (sicher ?? false) onEntfernen();
  }
}
