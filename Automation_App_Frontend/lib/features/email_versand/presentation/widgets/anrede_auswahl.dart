import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_bestand_fehler.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_bestand_leer.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_neutral_grund_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Wahl der Anrede je Mail (§4.7, §7.1) — Chips über dem Betreff, wie beim
/// Zusatzgruß.
///
/// **Gewählt wird nur der Anfang** („Sehr geehrter", „Guten Tag"): Anredewort
/// und Nachname setzt `Anredebaustein.zeileFuer` dazu, und die Beugung folgt
/// dem Geschlecht des Mandanten. Ein Baustein, der die ganze Zeile trüge,
/// stünde für genau einen Mandanten.
///
/// Der Chip zeigt deshalb **die fertige Zeile**, nicht den Anfang: „Sehr
/// geehrter Herr Müller" ist prüfbar, „Sehr geehrter" wäre eine Zusage.
///
/// Unter der Reihe steht seit dem 02.09.2026, **warum** die Zeile neutral ist
/// ([AnredeNeutralGrundZeile]), und der Umschalter „neutral anreden" wird
/// angeboten, sobald er etwas zu schalten hat. Beides kommt aus derselben
/// Beobachtung: „Sehr geehrte Damen und Herren" stand über Mails, ohne dass
/// jemand diese Anrede angelegt hatte, und war weder erklärt noch abstellbar.
class AnredeAuswahl extends StatelessWidget {
  const AnredeAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AnredebausteineCubit>()..ladenWennNoetig(),
      child: const AnredeChips(),
    );
  }
}

/// Die Chips selbst, unter dem bereitgestellten [AnredebausteineCubit].
class AnredeChips extends StatelessWidget {
  const AnredeChips({super.key});

  /// Der Satz über der Reihe, wenn die gewählte Vorlage **keine Stelle für die
  /// Anrede** hat; null heisst: es gibt eine. Dann geht die Mail ohne
  /// Anredezeile hinaus — und beide Reihen darüber sind wirkungslos, was bis
  /// zum 02.09.2026 niemand sagte.
  ///
  /// Aufbau und Wortlaut wie bei `GrussformelChips.hinweisFuer`: dieselbe Art
  /// Auskunft für die Zeile darunter, dieselbe Stelle, derselbe Weg zur
  /// Behebung. Zwei verschiedene Sätze für denselben Sachverhalt wären für den
  /// Anwalt zwei Dinge, die er auseinanderhalten muss.
  static String? hinweisFuer(EmailEntwurfState entwurf) =>
      entwurf.anredeMoeglich
      ? null
      : 'Die gewählte Vorlage hat keine Stelle dafür — dazu gehört der '
            'Platzhalter {{${MailPlatzhalter.anrede}}} in den Vorlagentext '
            '(Einstellungen ▸ E-Mail). Sonst geht die Mail ohne Anredezeile '
            'hinaus.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AnredebausteineCubit, AnredebausteineState>(
      builder: (context, bestand) {
        return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
          buildWhen: (vorher, jetzt) =>
              vorher.anredebaustein != jetzt.anredebaustein ||
              vorher.anredeNeutral != jetzt.anredeNeutral ||
              // Die Vorlage entscheidet, ob es überhaupt eine Anredezeile gibt
              // (`{{Anrede}}`) — und damit über alles darunter.
              vorher.gewaehlteVorlage != jetzt.gewaehlteVorlage ||
              // Beide gehören dazu, seit die Anredeart je Mail wählbar ist:
              // Auf dem Chip steht die **fertige Zeile**, und die beugt sich
              // mit — ohne diese zwei Zeilen zeigte er nach einem Wechsel von
              // „Herr" auf „Frau" weiter „Sehr geehrter Herr Müller".
              vorher.geschlecht != jetzt.geschlecht ||
              vorher.anredePersoenlichMoeglich !=
                  jetzt.anredePersoenlichMoeglich ||
              vorher.mitleserImAn != jetzt.mitleserImAn ||
              // Für den Grund unter der Reihe: Ohne Mandanten gibt es keine
              // namentliche Anrede, und das ist einer der Gründe.
              vorher.mandantBekannt != jetzt.mandantBekannt ||
              vorher.vorgang != jetzt.vorgang ||
              vorher.entwurf.alleEmpfaenger != jetzt.entwurf.alleEmpfaenger ||
              vorher.beschaeftigt != jetzt.beschaeftigt,
          builder: (context, entwurf) {
            final cubit = context.read<EmailEntwurfCubit>();
            final aktiv = !entwurf.beschaeftigt;

            if (bestand.bausteine.isEmpty) {
              // Zwei verschiedene Lagen, zwei Auskünfte — und keine davon ist
              // mehr das Verschwinden der Reihe (§4.7): Der **Ladefehler**
              // nennt den Grund und den Weg zurück, der **leere Bestand**
              // sagt, was stattdessen gilt. Denn gelöscht ist nur der
              // Bestand, nicht die Anredezeile: `Anredebaustein.rueckfall`
              // schreibt weiter.
              final fehler = bestand.fehler;
              if (fehler == null) return const AnredeBestandLeer();
              return AnredeBestandFehler(
                fehler: fehler,
                aktiv: aktiv,
                onErneut: context.read<AnredebausteineCubit>().laden,
              );
            }

            // Warum die Zeile neutral ist — gerechnet über denselben Erzeuger
            // wie die Chipbeschriftung, damit Auskunft und Zeile zueinander
            // passen. Null heisst: namentlich, oder selbst so gewählt.
            final grund = cubit.anredeNeutralGrund;
            // Ohne Stelle in der Vorlage gibt es keine Anredezeile — dann ist
            // „warum ist sie neutral" keine Frage mehr, und der Umschalter
            // hätte nichts zu schalten.
            final ohneStelle = hinweisFuer(entwurf);
            final namentlich =
                ohneStelle == null &&
                grund == null &&
                entwurf.anredeNeutral != true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('Anrede', style: theme.textTheme.labelLarge),
                  if (ohneStelle != null)
                    Text(
                      ohneStelle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final baustein in bestand.bausteine)
                        ChoiceChip(
                          label: Text(cubit.anredeVorschau(baustein)),
                          selected: entwurf.anredebaustein?.id == baustein.id,
                          onSelected: aktiv
                              ? (_) => cubit.waehleAnrede(baustein)
                              : null,
                        ),
                    ],
                  ),
                  // Angeboten, sobald er **etwas zu schalten hat** (geändert
                  // am 02.09.2026): Vorher hing der Umschalter an
                  // `anredePersoenlichMoeglich` und fehlte damit genau dann,
                  // wenn man ihn braucht — bei der Mail an die Versicherung,
                  // die den Mandanten trotzdem namentlich ansprechen soll.
                  if (ohneStelle == null &&
                      (cubit.anredeNamentlichMachbar ||
                          entwurf.anredeNeutral != null))
                    AnredeNeutralSchalter(
                      neutral: entwurf.anredeGehtNeutral,
                      aktiv: aktiv,
                      onUmschalten: cubit.setzeAnredeNeutral,
                    ),
                  if (grund != null && ohneStelle == null)
                    AnredeNeutralGrundZeile(grund: grund),
                  // Der Gegenfall: namentlich angeredet, obwohl jemand
                  // mitliest. Er darf nie neben dem Grund für die neutrale
                  // Anrede stehen — die zwei Sätze widersprächen sich.
                  if (entwurf.mitleserImAn && namentlich)
                    Text(
                      'Neben dem Mandanten steht noch jemand im Feld „An" '
                      'oder in Kopie — die namentliche Anrede liest er mit.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Der Umschalter „neutral anreden" — vorausgewählt nach Empfängerkreis und
/// Mandant, aber **änderbar** (§4.7): Wer trotz Mitleser namentlich anreden
/// will, darf das; die App weist darauf hin und entscheidet nicht.
class AnredeNeutralSchalter extends StatelessWidget {
  final bool neutral;
  final bool aktiv;

  /// null gibt die Entscheidung an den Empfängerkreis zurück.
  final ValueChanged<bool?> onUmschalten;

  const AnredeNeutralSchalter({
    super.key,
    required this.neutral,
    required this.aktiv,
    required this.onUmschalten,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: aktiv ? () => onUmschalten(!neutral) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: neutral,
                onChanged: aktiv ? (wert) => onUmschalten(wert ?? false) : null,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Neutral anreden („Damen und Herren")',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
