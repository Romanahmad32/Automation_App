import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_eintrag.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_katalog.dart';
import 'package:flutter/material.dart';

/// Die Platzhalter zum Anklicken, nach Gruppen geordnet — im Editor einer
/// Mail-Textvorlage (§4.7).
///
/// **Anklicken statt abtippen.** Vorher standen sechs Namen als Hilfetext unter
/// dem Feld, und die übrigen sechsundzwanzig musste der Anwalt erraten. Die
/// Auflösung ist eine Heuristik über Teilzeichenketten: `{{Schadennummer}}`
/// trifft die Versicherungsschein-Nr., `{{Adresse}}` trifft nichts — und
/// nichts davon sagt es ihm. Ein Klick fügt einen Namen ein, den es wirklich
/// gibt; dass er auflöst, sichert `feld_datenquelle_test.dart`.
///
/// Zugeklappt, weil das Schreiben im Vordergrund steht: Wer den Namen schon
/// kennt, tippt ihn weiter.
class PlatzhalterAuswahl extends StatelessWidget {
  /// Fügt den gewählten Platzhalter ein — der Editor entscheidet, wohin
  /// (Betreff oder Text, an der Schreibmarke).
  final ValueChanged<String> onEinfuegen;

  const PlatzhalterAuswahl({super.key, required this.onEinfuegen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eintraege = MailPlatzhalter.katalog();

    return Theme(
      // Ohne Trennlinien fügt sich der Aufklapper in das Formular ein, statt
      // es in zwei Hälften zu schneiden — wie in der Platzhalter-Übersicht.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        dense: true,
        leading: Icon(
          Icons.data_object,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Platzhalter einfügen (${eintraege.length})',
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          'Klick setzt ihn an der Schreibmarke ein.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          for (final gruppe in PlatzhalterKatalog.reihenfolge)
            if (PlatzhalterKatalog.inGruppe(eintraege, gruppe) case final drin
                when drin.isNotEmpty)
              PlatzhalterGruppenZeile(
                titel: gruppe.titel,
                eintraege: drin,
                onEinfuegen: onEinfuegen,
              ),
        ],
      ),
    );
  }
}

/// Eine Gruppe der Auswahl: Überschrift und die Platzhalter darunter.
class PlatzhalterGruppenZeile extends StatelessWidget {
  final String titel;
  final List<PlatzhalterEintrag> eintraege;
  final ValueChanged<String> onEinfuegen;

  const PlatzhalterGruppenZeile({
    super.key,
    required this.titel,
    required this.eintraege,
    required this.onEinfuegen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(titel, style: theme.textTheme.labelLarge),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final eintrag in eintraege)
                Tooltip
                // Der Klartext gehört an den Chip: „VersichererAnschrift"
                // allein sagt nicht, dass Name, Straße und Ort mitkommen.
                (
                  message: eintrag.bezeichnung,
                  child: ActionChip(
                    label: Text(
                      eintrag.platzhalter,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onEinfuegen(eintrag.geschrieben),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
