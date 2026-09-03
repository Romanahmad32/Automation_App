import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_fehlstelle_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagentext_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was die Platzhalter der gewählten Vorlage ergeben haben (§4.7) — und was
/// leer blieb.
///
/// **Zwei Teile mit verschiedenem Anspruch.** Was leer blieb, steht **offen**
/// da: Im gefüllten Text ist davon nichts mehr zu sehen, der Platzhalter hat
/// seine Zeile mitgenommen. Die vollständige Liste bleibt dagegen zugeklappt —
/// sie beantwortet eine Frage, die sich nur manchmal stellt.
///
/// Vorher war beides ein Aufklapper mit einer Zahl im Titel, und die Zahl hat
/// niemand gelesen. Der Ton folgt jetzt dem übrigen Hinweiswesen der App
/// (`VorgangFehlendeDatenHinweis`): `tertiary`, kein Alarmrot — ein fehlender
/// Zusatzgruß ist kein Fehler.
class PlatzhalterUebersicht extends StatelessWidget {
  const PlatzhalterUebersicht({super.key});

  /// Die Überschrift über den leeren Platzhaltern. Der Plural steht hier und
  /// nicht im Widget, damit er einzeln prüfbar ist.
  static String fehlstellenTitel(int leer) =>
      leer == 1 ? 'Ein Platzhalter ohne Wert' : '$leer Platzhalter ohne Wert';

  /// Ob sich an den **Werten** etwas geändert hat, die die Übersicht zeigt.
  ///
  /// Steht hier und nicht als Ausdruck im `buildWhen`, weil sie prüfbar sein
  /// muss: Genau eine vergessene Zeile war der Fehler (03.09.2026). Die
  /// Anredeart fehlte, und weil das Widget im Formular als `const` steht,
  /// wurde es auch von oben nicht neu gebaut — nach einem Klick auf „Frau"
  /// behauptete die Übersicht weiter „Mandant", während im Textfeld darunter
  /// schon „Mandantin" stand. Sie ist die Liste dessen, was
  /// `EmailEntwurfCubit.fuellerFuer` liest; wer dort etwas ergänzt, ergänzt
  /// es hier.
  ///
  /// `geschlecht` deckt beide Wege ab: die je Mail gewählte Anredeart und die
  /// des Registereintrags.
  static bool neuZeichnen(EmailEntwurfState vorher, EmailEntwurfState jetzt) =>
      vorher.gewaehlteVorlage != jetzt.gewaehlteVorlage ||
      vorher.zusatzgruss != jetzt.zusatzgruss ||
      vorher.anredebaustein != jetzt.anredebaustein ||
      vorher.anredeNeutral != jetzt.anredeNeutral ||
      vorher.geschlecht != jetzt.geschlecht ||
      vorher.vorgang != jetzt.vorgang ||
      // Über [listEquals] und nicht über `!=` (behoben am 03.09.2026):
      // `alleEmpfaenger` baut bei **jedem** Aufruf eine neue Liste
      // (`[...an, ...kopie]`), und Dart vergleicht Listen über die Identität.
      // Der Ausdruck war damit immer wahr, `buildWhen` immer erfüllt und die
      // ganze Aufzählung darüber wirkungslos — was die fehlende Anredeart
      // gleich mit verdeckte: Neu gezeichnet wurde ja doch, nur bei jedem
      // Tastendruck im Nachrichtentext.
      !listEquals(vorher.entwurf.alleEmpfaenger, jetzt.entwurf.alleEmpfaenger);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
      buildWhen: neuZeichnen,
      builder: (context, stand) {
        final vorlage = stand.gewaehlteVorlage;
        if (vorlage == null) return const SizedBox.shrink();

        // null heisst: Der Dialog lädt noch (kein Erzeuger), es gibt nichts
        // zu füllen. Vorher stand hier ein `!` im Cubit, und eine im
        // Ladefenster gewählte Vorlage riss den `build` mit einem Nullfehler
        // auf (behoben am 02.09.2026).
        final fueller = context.read<EmailEntwurfCubit>().fuellerFuer(
          stand.entwurf.alleEmpfaenger,
        );
        if (fueller == null) return const SizedBox.shrink();

        final befunde = fueller.befunde(vorlage);
        if (befunde.isEmpty) return const SizedBox.shrink();

        final leere = befunde.where((befund) => befund.istLeer).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leere.isNotEmpty) ...[
                Text(
                  fehlstellenTitel(leere.length),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final befund in leere)
                  PlatzhalterFehlstelleZeile(befund: befund),
              ],
              PlatzhalterListe(vorlage: vorlage, befunde: befunde),
            ],
          ),
        );
      },
    );
  }
}

/// Die vollständige Liste — zugeklappt, mit dem Weg in den Vorlagentext.
class PlatzhalterListe extends StatelessWidget {
  final MailVorlage vorlage;
  final List<PlatzhalterBefund> befunde;

  const PlatzhalterListe({
    super.key,
    required this.vorlage,
    required this.befunde,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      // Ohne Trennlinien fügt sich der Aufklapper in das Formular ein, statt
      // es in zwei Hälften zu schneiden.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        dense: true,
        title: Text(
          'Alle Platzhalter (${befunde.length})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.difference_outlined, size: 18),
          label: const Text('Vorlage und Ergebnis'),
          onPressed: () => VorlagentextDialog.zeigen(
            context,
            vorlage: vorlage,
            befunde: befunde,
          ),
        ),
        children: [
          for (final befund in befunde) PlatzhalterZeile(befund: befund),
        ],
      ),
    );
  }
}
