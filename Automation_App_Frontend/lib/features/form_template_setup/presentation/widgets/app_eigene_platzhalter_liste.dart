import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:flutter/material.dart';

/// Nachschlagewerk in der Vorlagenverwaltung: welche {{Platzhalter}} die App
/// beim Erzeugen selbst füllt, was sie einsetzen und wie das aussieht (#31).
///
/// Die Werte gab es längst — nur wusste es niemand: `{{RvgBrutto}}` errät man
/// nicht, und wer ihn nicht kennt, tippt die Anwaltskosten von Hand in einen
/// Brief, den die App hätte rechnen können. Zugeklappt, weil es Nachschlagen
/// ist und keine Aufgabe: Wer eine Vorlage einrichtet, soll es finden, wenn er
/// es sucht, und sonst nicht im Weg stehen.
class AppEigenePlatzhalterListe extends StatelessWidget {
  const AppEigenePlatzhalterListe({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome),
        title: const Text('Diese Platzhalter füllt die App selbst'),
        subtitle: Text(
          'In jede Vorlage schreibbar — ohne Eingabefeld.',
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppEigenePlatzhalter.beispiel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final eintrag in AppEigenePlatzhalter.eintraege)
            AppEigenerPlatzhalterZeile(eintrag: eintrag),
        ],
      ),
    );
  }
}

/// Eine Zeile der Liste: Name und Beispielausgabe nebeneinander, die Erklärung
/// darunter. Zwei Zeilen statt drei Spalten, damit auch ein schmales Fenster
/// nichts abschneidet.
class AppEigenerPlatzhalterZeile extends StatelessWidget {
  final AppEigenerPlatzhalter eintrag;

  const AppEigenerPlatzhalterZeile({super.key, required this.eintrag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: SelectableText(
                  '{{${eintrag.name}}}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                eintrag.beispiel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            eintrag.erklaerung,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
