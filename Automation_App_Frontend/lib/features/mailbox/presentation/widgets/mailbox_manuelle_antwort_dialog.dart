import 'package:automation_app/features/mailbox/presentation/utils/zentralruf_uebernahme.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/manual_reply_input.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der manuelle Weg (§4.3): eine Zentralruf-Antwortmail einfügen oder als
/// Datei laden, auswerten lassen und die erkannten Daten übernehmen.
///
/// Seit dem Umbau zu Issue #134 ein Dialog statt einer eigenen Spalte: Der
/// Posteingang selbst ist der Normalfall, der manuelle Weg die Ausnahme für
/// Mails, die nicht über das überwachte Postfach kamen. Eine Ausnahme, die
/// dauerhaft die halbe Fläche belegt, drängt den Normalfall an den Rand.
/// [ManualReplyInput] und [VorgangsdatenForm] bleiben dabei unverändert —
/// dieser Dialog setzt sie nur neu zusammen.
class MailboxManuelleAntwortDialog extends StatelessWidget {
  const MailboxManuelleAntwortDialog({super.key});

  /// Öffnet den Dialog über dem [ZentralrufReplyBloc] der Seite und liefert
  /// true, wenn übernommen wurde — dann wechselt die aufrufende Ansicht zum
  /// Word-Assistenten.
  ///
  /// Der Bloc wird **hineingereicht**, nicht neu erzeugt: Der Dialog hängt am
  /// Navigator-Overlay, dessen Kontext die Blocs der Seite nicht mehr sieht.
  /// Vorher und nachher zurückgesetzt, damit ein zweiter Aufruf nicht mit dem
  /// Ergebnis des ersten aufgeht.
  static Future<bool> zeigen(BuildContext context) async {
    final bloc = context.read<ZentralrufReplyBloc>();
    bloc.add(const ResetZentralrufReplyEvent());
    final ergebnis = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider<ZentralrufReplyBloc>.value(
        value: bloc,
        child: const MailboxManuelleAntwortDialog(),
      ),
    );
    bloc.add(const ResetZentralrufReplyEvent());
    return ergebnis ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Antwort manuell einfügen'),
      content: SizedBox(
        width: 620,
        // Gedeckelte Höhe statt freier: Das ausgewertete Formular ist lang
        // (ein Feld je erkannter Angabe) und scrollt selbst; ohne Deckel
        // wüchse der Dialog über den Schirm hinaus.
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: BlocBuilder<ZentralrufReplyBloc, ZentralrufReplyState>(
          builder: (context, state) => switch (state) {
            // Fehler stehen nicht hier, sondern als Rückmeldung: Die Seite
            // lauscht ohnehin auf den Bloc — und ein Dialog, der bei einem
            // Auswertungsfehler nur noch die Meldung zeigt, ist eine
            // Sackgasse. So bleibt das Eingabefeld für den zweiten Versuch.
            ZentralrufReplyParsed(result: final ergebnis) => VorgangsdatenForm(
              key: ObjectKey(ergebnis),
              data: ergebnis.data,
              warnings: ergebnis.warnings,
              onUebernehmen: (daten, zielReferenz) =>
                  _uebernehmen(context, daten, zielReferenz),
            ),
            _ => const ManualReplyInput(),
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Future<void> _uebernehmen(
    BuildContext context,
    ZentralrufReplyData daten,
    String? zielReferenz,
  ) async {
    final uebernommen = await uebernimmZentralrufDaten(
      context,
      daten,
      zielReferenz: zielReferenz,
    );
    if (!uebernommen || !context.mounted) return;
    Navigator.pop(context, true);
  }
}
