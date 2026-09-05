import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_spalten.dart';
import 'package:flutter/material.dart';

/// Der Tabellenkopf über den Feldzeilen des Vorlageneditors.
///
/// Er hält **keine** eigene Spaltenaufteilung mehr: Aufschriften, Breiten und
/// Flex-Anteile kommen aus [FelderSpalten], genau wie in der Feldzeile
/// darunter. Vorher standen zwei Listen nebeneinander, und der Kopf verschob
/// sich gegen die Zeile, sobald jemand nur eine von beiden anfasste.
///
/// Er steht als eigenes Widget **über** der Liste, nicht in ihr — in Stufe 3
/// bekommt die Liste einen eigenen Scrollbereich, und dann bleibt der Kopf
/// beim Scrollen stehen, ohne dass sich hier etwas ändern muss.
class TemplateFieldsTableHeader extends StatelessWidget {
  const TemplateFieldsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stil = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FelderSpalten.kopfEinrueckung,
        vertical: 8,
      ),
      child: FelderSpalten.zeile([
        for (final spalte in FelderSpalten.alle) _kopf(spalte, stil),
      ]),
    );
  }

  /// Eine Aufschrift. Bei angehobener Schrift (Issue #57) und schmaler Spalte
  /// bräche ein Wort wie „Bezeichnung" sonst mitten hindurch, weil Text ohne
  /// Vorgabe umbricht — eine Kopfzeile ist aber eine Beschriftung und kein
  /// Fließtext: Hier gewinnt die Auslassung vor dem Umbruch, und der volle
  /// Text steht im Tooltip.
  static Widget _kopf(FelderSpalte spalte, TextStyle? stil) {
    if (spalte.beschriftung.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: spalte.beschriftung,
      child: Text(
        spalte.beschriftung,
        style: stil,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
