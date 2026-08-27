import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_senden_bestaetigung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_inhalt.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau_dialog.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mail verfassen und versenden (§4.7). Mit [vorgang] sind Empfänger, Betreff
/// und Anrede vorbelegt; ohne ihn entsteht ein leeres Anschreiben — Anrede und
/// Grußformel stehen, alles andere schreibt der Anwalt.
///
/// Der Dialog liest **nichts** aus dem Kontext: Er wird aus zwei Tabs heraus
/// geöffnet (Word-Assistent und Postfach), deren Blocs nichts miteinander zu
/// tun haben, und aus einem anderen Dialog heraus, dessen Kontext ohnehin am
/// Navigator-Overlay hängt. Alles Nötige holt sich der Cubit selbst.
class EmailVersandDialog extends StatelessWidget {
  final Vorgang? vorgang;
  final Mandant? mandant;

  /// Eine noch nicht übernommene Zentralruf-Antwort (Postfach): liefert die
  /// Versichereradresse, die am Vorgang noch nicht steht.
  final ZentralrufReplyData? antwort;

  /// Anhänge, die von vornherein dranhängen — üblicherweise das
  /// Anspruchsschreiben als PDF.
  final List<String> anhangVorauswahl;

  /// Weitere Dateien aus dem Fall-Ordner, zum Anklicken.
  final List<String> ausDerAkte;

  const EmailVersandDialog({
    super.key,
    this.vorgang,
    this.mandant,
    this.antwort,
    this.anhangVorauswahl = const [],
    this.ausDerAkte = const [],
  });

  /// Öffnet den Dialog und liefert das Ergebnis, wenn gesendet wurde — sonst
  /// null (abgebrochen).
  static Future<EmailVersandErgebnis?> zeigen(
    BuildContext context, {
    Vorgang? vorgang,
    Mandant? mandant,
    ZentralrufReplyData? antwort,
    List<String> anhangVorauswahl = const [],
    List<String> ausDerAkte = const [],
  }) {
    return showDialog<EmailVersandErgebnis>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmailVersandDialog(
        vorgang: vorgang,
        mandant: mandant,
        antwort: antwort,
        anhangVorauswahl: anhangVorauswahl,
        ausDerAkte: ausDerAkte,
      ),
    );
  }

  Future<void> _senden(BuildContext context, EmailEntwurfState state) async {
    final cubit = context.read<EmailEntwurfCubit>();
    final bestaetigt = await EmailSendenBestaetigung.zeigen(
      context,
      entwurf: state.entwurf,
      absender: state.bereitschaft?.absender ?? '',
      signatur: state.bereitschaft?.signatur ?? '',
    );
    if (!bestaetigt) return;

    final erfolg = await cubit.senden();
    if (!erfolg || !context.mounted) return;
    Navigator.pop(context, cubit.state.ergebnis);
  }

  /// Übergibt an Outlook und lässt den Dialog **stehen**. Der Anwalt sieht dort
  /// noch, was er übergeben hat, und kann nachbessern und erneut übergeben —
  /// das Outlook-Fenster liegt womöglich hinter der App, und ein Dialog, der
  /// sich einfach schließt, sieht aus wie ein verschluckter Klick.
  Future<void> _entwurfOeffnen(BuildContext context) async {
    await context.read<EmailEntwurfCubit>().entwurfOeffnen();
  }

  /// „Öffnet…" waehrend der Uebergabe, danach „Erneut oeffnen" — Outlook
  /// braucht kalt spuerbar Zeit, und ohne diesen Wechsel weiss niemand, ob der
  /// erste Klick angekommen ist.
  static String _entwurfBeschriftung(EmailEntwurfState state) {
    if (state.uebergibtGerade) return 'Öffnet…';
    return state.entwurfErgebnis == null
        ? 'In Outlook öffnen'
        : 'Erneut in Outlook öffnen';
  }

  /// Die Mail ansehen, ohne sie abzuschicken — der Weg für schmale Fenster.
  /// Ist Platz für die Seitenspalte, steht die Vorschau ohnehin schon da und
  /// dieser Knopf entfällt.
  Future<void> _vorschau(BuildContext context, EmailEntwurfState state) {
    return EmailVorschauDialog.zeigen(
      context,
      entwurf: state.entwurf,
      absender: state.bereitschaft?.absender ?? '',
      signatur: state.bereitschaft?.signatur ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EmailEntwurfCubit>()
        ..starte(
          vorgang: vorgang,
          mandant: mandant,
          antwort: antwort,
          anhangPfade: anhangVorauswahl,
        ),
      child: BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
        builder: (context, state) {
          return AlertDialog(
            title: const Text('E-Mail versenden'),
            content: EmailVersandInhalt(state: state, ausDerAkte: ausDerAkte),
            actions: [
              TextButton(
                onPressed: state.beschaeftigt
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              if (!EmailVersandInhalt.zweispaltig(context))
                TextButton.icon(
                  onPressed: state.beschaeftigt
                      ? null
                      : () => _vorschau(context, state),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Vorschau'),
                ),
              OutlinedButton.icon(
                onPressed: state.kannEntwurfOeffnen
                    ? () => _entwurfOeffnen(context)
                    : null,
                icon: state.uebergibtGerade
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        state.entwurfErgebnis == null
                            ? Icons.drive_file_move_outline
                            : Icons.refresh,
                      ),
                label: Text(_entwurfBeschriftung(state)),
              ),
              FilledButton.icon(
                onPressed: state.kannSenden
                    ? () => _senden(context, state)
                    : null,
                icon: state.sendetGerade
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(state.sendetGerade ? 'Sendet…' : 'Senden'),
              ),
            ],
          );
        },
      ),
    );
  }
}
