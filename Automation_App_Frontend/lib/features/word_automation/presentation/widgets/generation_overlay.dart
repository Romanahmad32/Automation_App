import 'package:flutter/material.dart';

/// Abdunkelndes Overlay mit Spinner, solange das Backend das Dokument erzeugt.
/// Wird im Fill-Out- und im Schadensaufstellungs-Schritt über den Inhalt gelegt.
class GenerationOverlay extends StatelessWidget {
  const GenerationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black38,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Dokument wird erstellt …',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
