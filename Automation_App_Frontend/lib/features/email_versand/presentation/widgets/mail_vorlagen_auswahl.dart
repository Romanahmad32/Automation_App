import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Wahl der Mail-Textvorlage im Versanddialog (§4.7). Die gewählte ersetzt
/// Betreff und Text; die Platzhalter füllt der Cubit aus dem Vorgang.
///
/// **Ohne Vorlagen im Bestand ist hier nichts** — kein leeres Auswahlfeld, das
/// nach einer Einstellung aussieht, die es nicht gibt. Bis eine angelegt ist,
/// belegt die App Betreff und Text wie bisher aus den Vorgangsdaten vor.
///
/// Die Auswahl **errät nichts.** Standardmässig gehen Mandant und Versicherung
/// eine gemeinsame Mail; welche Vorlage dort passt, weiss nur der Anwalt, und
/// eine automatisch gesetzte Mandantenvorlage stünde vor der Gegenseite.
class MailVorlagenAuswahl extends StatelessWidget {
  const MailVorlagenAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<MailVorlagenCubit>()..ladenWennNoetig(),
      child: const MailVorlagenAuswahlFeld(),
    );
  }
}

/// Das Auswahlfeld selbst, unter dem bereitgestellten [MailVorlagenCubit].
class MailVorlagenAuswahlFeld extends StatelessWidget {
  const MailVorlagenAuswahlFeld({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailVorlagenCubit, MailVorlagenState>(
      builder: (context, bestand) {
        if (bestand.vorlagen.isEmpty) return const SizedBox.shrink();

        return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
          buildWhen: (vorher, jetzt) =>
              vorher.gewaehlteVorlage != jetzt.gewaehlteVorlage ||
              vorher.beschaeftigt != jetzt.beschaeftigt,
          builder: (context, entwurf) {
            // Der Eintrag „keine" trägt `null` als Wert — dieselbe Bedeutung
            // wie im Zustand, damit das Abwählen kein Sonderfall ist.
            final gewaehlt = bestand.vorlagen
                .where((vorlage) => vorlage.id == entwurf.gewaehlteVorlage?.id)
                .firstOrNull;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<MailVorlage?>(
                // Der Schluessel haengt an der Wahl: `initialValue` saet ein
                // FormField nur beim ersten Aufbau.
                key: ValueKey(entwurf.gewaehlteVorlage?.id ?? 0),
                initialValue: gewaehlt,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Textvorlage',
                  helperText:
                      'Ersetzt Betreff und Text. Danach ist alles änderbar.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<MailVorlage?>(
                    child: Text('Keine Vorlage (Vorbelegung aus dem Vorgang)'),
                  ),
                  for (final vorlage in bestand.vorlagen)
                    DropdownMenuItem<MailVorlage?>(
                      value: vorlage,
                      child: Text(
                        vorlage.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: entwurf.beschaeftigt
                    ? null
                    : context.read<EmailEntwurfCubit>().waehleVorlage,
              ),
            );
          },
        );
      },
    );
  }
}
