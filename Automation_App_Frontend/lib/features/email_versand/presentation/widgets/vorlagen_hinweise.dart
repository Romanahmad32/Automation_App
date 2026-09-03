import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/vorlagen_mangel.dart';
import 'package:automation_app/features/email_versand/domain/services/vorlagen_pruefung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/beugung_vorschau.dart';
import 'package:flutter/material.dart';

/// Was der Editor über die eben getippte Vorlage sagt (§4.7, ergänzt am
/// 02.09.2026): Platzhalter, die nichts liefern werden, und was die Beugungen
/// ergeben.
///
/// **Zieht beim Tippen nach**, über die Controller der beiden Felder. Ein
/// eigenes `setState` im Dialog wäre der zweite Weg zum selben Ziel — die
/// Controller sind ohnehin `Listenable`, und nur dieser Block muss neu bauen,
/// nicht der ganze Dialog.
///
/// **Und er verweigert nichts** (§1.3): Eine halb geschriebene Vorlage muss
/// sich speichern lassen. Ob ein Name gemeint war, weiß der Anwalt besser als
/// eine Heuristik über Teilzeichenketten — sie sagt, was sie sieht, und hält
/// den Knopf nicht auf.
class VorlagenHinweise extends StatelessWidget {
  final TextEditingController betreff;
  final TextEditingController text;

  const VorlagenHinweise({
    super.key,
    required this.betreff,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([betreff, text]),
      builder: (context, _) {
        final vorlage = MailVorlage(betreff: betreff.text, text: text.text);
        final maengel = VorlagenPruefung.maengel(vorlage);
        final beugungen = VorlagenPruefung.beugungen(vorlage);
        if (maengel.isEmpty && beugungen.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            if (maengel.isNotEmpty) VorlagenMaengelListe(maengel: maengel),
            BeugungVorschau(beugungen: beugungen),
          ],
        );
      },
    );
  }
}

/// Die Platzhalter, die nichts liefern werden — mit Begründung je Zeile.
///
/// Im Ton der übrigen Hinweise (`tertiary`, kein Alarmrot): Ein Platzhalter,
/// der noch nicht auflöst, ist kein Fehler, sondern eine Vorlage im Werden.
class VorlagenMaengelListe extends StatelessWidget {
  final List<VorlagenMangel> maengel;

  const VorlagenMaengelListe({super.key, required this.maengel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ton = theme.colorScheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Icons.playlist_add_check_circle_outlined,
              size: 18,
              color: ton,
            ),
            Expanded(
              child: Text(
                titelFuer(maengel.length),
                style: theme.textTheme.labelLarge?.copyWith(color: ton),
              ),
            ),
          ],
        ),
        for (final mangel in maengel)
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mangel.geschrieben,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: ton,
                  ),
                ),
                Text(
                  mangel.hinweis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Die Überschrift samt gebeugtem Plural. Öffentlich, weil ein Test darauf
  /// zeigt — „1 Platzhalter liefern nichts" wäre ein Schnitzer in einer App,
  /// die deutsche Briefe schreibt.
  static String titelFuer(int anzahl) => anzahl == 1
      ? 'Ein Platzhalter liefert nichts'
      : '$anzahl Platzhalter liefern nichts';
}
