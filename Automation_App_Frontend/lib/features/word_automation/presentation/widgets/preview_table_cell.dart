import 'package:flutter/material.dart';

/// Eine Zelle der Schadensaufstellungs-Vorschau im Dokument-Look: kompaktes
/// Padding, optional rechtsbündig (für Beträge) und mit eigenem Textstil.
class PreviewTableCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool alignRight;

  const PreviewTableCell(
    this.text, {
    super.key,
    this.style,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: style,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }
}
