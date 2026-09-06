import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_eintrag.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_katalog.dart';
import 'package:flutter/material.dart';

/// Die Platzhalter zum Anklicken, nach Gruppen geordnet — im Editor einer
/// Mail-Textvorlage und im Versanddialog (§4.7).
///
/// **Anklicken statt abtippen.** Vorher standen sechs Namen als Hilfetext unter
/// dem Feld, und die übrigen sechsundzwanzig musste der Anwalt erraten. Die
/// Auflösung ist eine Heuristik über Teilzeichenketten: `{{Schadennummer}}`
/// trifft die Versicherungsschein-Nr., `{{Adresse}}` trifft nichts — und
/// nichts davon sagt es ihm. Ein Klick fügt einen Namen ein, den es wirklich
/// gibt; dass er auflöst, sichert `feld_datenquelle_test.dart`.
///
/// **Offen, nicht zugeklappt** (geändert am 06.09.2026): Der Aufklapper war
/// beim Anlegen einer Vorlage zu, und wer die erste schreibt, weiss gerade
/// nicht, welche Platzhalter es gibt (§4.7). Zugeklappt half er genau dem, der
/// ihn nicht braucht.
///
/// **Wohin eingefügt wird, steht dabei.** Das Ziel führt
/// [PlatzhalterEinfuegeZiel]; die Kopfzeile nennt es, und die Beschriftung des
/// getroffenen Feldes ebenso.
class PlatzhalterAuswahl extends StatelessWidget {
  /// Betreff und Text samt der Frage, welches von beiden ein Klick trifft.
  final PlatzhalterEinfuegeZiel ziel;

  const PlatzhalterAuswahl({super.key, required this.ziel});

  /// Die Kopfzeile über den Chips. Öffentlich, weil ein Test darauf zeigt: Sie
  /// ist die eine Stelle, an der das Einfügeziel benannt wird.
  static String kopfzeile(String zielName) =>
      'Platzhalter einfügen — Ziel: $zielName';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eintraege = MailPlatzhalter.katalog();

    return AnimatedBuilder(
      animation: ziel,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(
                Icons.data_object,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  kopfzeile(ziel.zielName),
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          Text(
            'Der Klick setzt ihn an der Schreibmarke ein. Wer in das andere '
            'Feld klickt, verlegt damit das Ziel.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final gruppe in PlatzhalterKatalog.reihenfolge)
            if (PlatzhalterKatalog.inGruppe(eintraege, gruppe) case final drin
                when drin.isNotEmpty)
              PlatzhalterGruppenZeile(
                titel: gruppe.titel,
                eintraege: drin,
                onEinfuegen: ziel.fuegeEin,
              ),
        ],
      ),
    );
  }
}

/// Eine Gruppe der Auswahl: Überschrift und die Platzhalter darunter.
///
/// Die Chips sind [ActionChip]s und keine [ChoiceChip]s — sie **tun** etwas
/// (einfügen), sie wählen nichts aus. Das Vokabular dazu steht in
/// `AuswahlThemes`.
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
      padding: const EdgeInsets.only(bottom: 4),
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
