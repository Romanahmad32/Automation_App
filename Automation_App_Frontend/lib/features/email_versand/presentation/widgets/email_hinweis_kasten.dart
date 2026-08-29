import 'package:flutter/material.dart';

/// Farbig hinterlegte Hinweiszeile mit Symbol — der Kasten über dem
/// Mail-Formular, in dem Absender, Warnung oder Fehler steht.
///
/// Eigener, öffentlicher Typ statt eines privaten Bausteins im Hinweis-Widget:
/// Die drei Fälle unterscheiden sich nur in Farbe, Symbol und Text, und ein
/// vierter (etwa „gesendet") kommt sicher noch dazu.
class EmailHinweisKasten extends StatelessWidget {
  final Color farbe;
  final Color vordergrund;
  final IconData symbol;
  final String text;

  const EmailHinweisKasten({
    super.key,
    required this.farbe,
    required this.vordergrund,
    required this.symbol,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: farbe,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(symbol, size: 20, color: vordergrund),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: vordergrund),
            ),
          ),
        ],
      ),
    );
  }
}
