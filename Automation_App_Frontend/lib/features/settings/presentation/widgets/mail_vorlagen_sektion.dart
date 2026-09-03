import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/hinzufuegen_button.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_state.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Verwaltung der Mail-Textvorlagen (§4.7, §5.3) — im Reiter „E-Mail",
/// neben der Signatur, die denselben Weg hinausgeht.
///
/// **Kein Speichern-Knopf der Seite.** Anders als Kanzleidaten und Signatur ist
/// jede Vorlage ein eigener Satz im Bestand: Der Dialog schreibt sie sofort,
/// und Anlegen wie Entfernen wirken ohne Umweg. Ein Sammelknopf müsste eine
/// Liste mit Zugängen und Abgängen zusammenrechnen, um dasselbe zu erreichen.
class MailVorlagenSektion extends StatelessWidget {
  const MailVorlagenSektion({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<MailVorlagenCubit>()..ladenWennNoetig(),
      child: const MailVorlagenSektionInhalt(),
    );
  }
}

/// Der Abschnitt selbst, unter dem bereitgestellten [MailVorlagenCubit].
class MailVorlagenSektionInhalt extends StatelessWidget {
  const MailVorlagenSektionInhalt({super.key});

  Future<void> _bearbeite(BuildContext context, MailVorlage vorlage) {
    final cubit = context.read<MailVorlagenCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          MailVorlageDialog(vorlage: vorlage, onSpeichern: cubit.speichere),
    );
  }

  Future<void> _entferne(BuildContext context, MailVorlage vorlage) async {
    final cubit = context.read<MailVorlagenCubit>();
    final sicher = await bestaetigen(
      context,
      icon: Icons.warning_rounded,
      titel: 'Vorlage entfernen?',
      text:
          '„${vorlage.name}" wird aus dem Bestand gelöscht. Bereits '
          'versendete Mails bleiben davon unberührt.',
      bestaetigung: 'Entfernen',
      destruktiv: true,
    );
    if (sicher) await cubit.loesche(vorlage.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailVorlagenCubit, MailVorlagenState>(
      builder: (context, stand) {
        return FormSection(
          icon: Icons.article_outlined,
          title: 'Mail-Textvorlagen',
          subtitle:
              'Betreff und Anschreiben, aus denen Sie beim Verfassen wählen. '
              'Platzhalter wie {{Anrede}} füllt die App aus dem Vorgang.',
          trailing: stand.laedt
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          children: [
            if (stand.fehler != null)
              Text(
                stand.fehler!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (stand.geladen && stand.vorlagen.isEmpty)
              const Text(
                'Noch keine Vorlage hinterlegt. Ohne Vorlage belegt die App '
                'Betreff und Text wie bisher aus den Vorgangsdaten vor.',
              ),
            for (final vorlage in stand.vorlagen)
              MailVorlageZeile(
                vorlage: vorlage,
                onBearbeiten: () => _bearbeite(context, vorlage),
                onEntfernen: () => _entferne(context, vorlage),
              ),
            HinzufuegenButton(
              beschriftung: 'Vorlage hinzufügen',
              onHinzufuegen: () => _bearbeite(context, const MailVorlage()),
            ),
          ],
        );
      },
    );
  }
}
