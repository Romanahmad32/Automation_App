import 'dart:math' as math;

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_senden_bestaetigung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_formular.dart';
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
    );
    if (!bestaetigt) return;

    final erfolg = await cubit.senden();
    if (!erfolg || !context.mounted) return;
    Navigator.pop(context, cubit.state.ergebnis);
  }

  /// Übergibt an Outlook und schließt den Dialog: Weitergearbeitet wird dort,
  /// und ein danach noch offener Entwurf in der App lüde zum zweiten Versand
  /// derselben Mail ein. Der Hinweis geht über den ScaffoldMessenger der
  /// Anwendung — der überlebt das Schließen, der Dialogkontext nicht.
  Future<void> _entwurfOeffnen(BuildContext context) async {
    final cubit = context.read<EmailEntwurfCubit>();
    final melder = ScaffoldMessenger.of(context);

    final ergebnis = await cubit.entwurfOeffnen();
    if (ergebnis == null || !context.mounted) return;

    Navigator.pop(context);
    melder.showSnackBar(
      SnackBar(
        content: Text(
          ergebnis.hinweis ??
              'Der Entwurf ist in Outlook geöffnet — mit Ihrer Signatur. '
                  'Gesendet wird dort.',
        ),
        duration: const Duration(seconds: 6),
      ),
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
            content: SizedBox(
              // Breit genug für Empfängerzeilen und Anhangs-Chips, aber nie
              // breiter als das Fenster: Der Dialog läuft auch auf einem
              // 1366er-Laptop, und ein fester Wert überliefe dort.
              width: math.min(720, MediaQuery.sizeOf(context).width - 120),
              child: SingleChildScrollView(
                child: EmailVersandFormular(ausDerAkte: ausDerAkte),
              ),
            ),
            actions: [
              TextButton(
                onPressed: state.beschaeftigt
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
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
                    : const Icon(Icons.drive_file_move_outline),
                label: Text(
                  state.uebergibtGerade ? 'Öffnet…' : 'In Outlook öffnen',
                ),
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
