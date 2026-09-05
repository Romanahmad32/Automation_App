import 'package:flutter/material.dart';

class TemplateFieldsTableHeader extends StatelessWidget {
  const TemplateFieldsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    // Bei angehobener Schrift (Issue #57) und schmaler Spalte brach ein Wort
    // wie „BEZEICHNUNG" sonst mitten hindurch, weil Text ohne Vorgabe auf
    // mehrere Zeilen umbricht. Eine Kopfzeile ist eine Beschriftung, kein
    // Fließtext — hier gewinnt die Abkürzung (Ellipsis) vor dem Umbruch.
    Widget kopf(String text) => Text(
      text,
      style: textStyle,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 65), // Spacer for drag icon
          Expanded(flex: 3, child: kopf('BEZEICHNUNG')),
          Expanded(flex: 2, child: kopf('TYP')),
          Expanded(flex: 3, child: kopf('DATENQUELLE')),
          Expanded(flex: 2, child: kopf('ANFORDERUNG')),
          const SizedBox(width: 48), // Spacer for delete button
        ],
      ),
    );
  }
}
