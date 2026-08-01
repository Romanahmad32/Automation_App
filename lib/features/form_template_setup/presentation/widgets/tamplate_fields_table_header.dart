import 'package:flutter/material.dart';

class TemplateFieldsTableHeader extends StatelessWidget {
  const TemplateFieldsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 65), // Spacer for drag icon
          Expanded(flex: 3, child: Text('BEZEICHNUNG', style: textStyle)),
          Expanded(flex: 2, child: Text('TYP', style: textStyle)),
          Expanded(flex: 3, child: Text('DATENQUELLE', style: textStyle)),
          Expanded(flex: 2, child: Text('ANFORDERUNG', style: textStyle)),
          const SizedBox(width: 48), // Spacer for delete button
        ],
      ),
    );
  }
}
