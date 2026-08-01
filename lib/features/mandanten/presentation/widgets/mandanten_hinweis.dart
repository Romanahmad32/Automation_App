import 'package:flutter/material.dart';

/// Zentrierter, gedämpfter Hinweistext in der Mandantenübersicht (z. B. „keine
/// Treffer" oder „noch keine Mandanten").
class MandantenHinweis extends StatelessWidget {
  final String text;

  const MandantenHinweis(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
