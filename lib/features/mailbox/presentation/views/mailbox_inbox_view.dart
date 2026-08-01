import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_detail_pane.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_reply_list.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_banner.dart';
import 'package:automation_app/features/vorgaenge/domain/services/antwort_konflikte.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/antwort_konflikt_dialog.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Vereinte Ansicht „Zentralruf-Antworten": oben der Verbindungsstatus der
/// Überwachung, links die automatisch erfassten Treffer plus der Einstieg
/// „Manuell einfügen", rechts das gemeinsame, editierbare Vorgangsdaten-Formular
/// ([VorgangsdatenForm]) — egal ob die Antwort per Postfach kam oder von Hand
/// eingefügt wurde. „Übernehmen" füllt den Vorgang vor und wechselt zu Word.
class MailboxInboxView extends StatefulWidget {
  const MailboxInboxView({super.key});

  @override
  State<MailboxInboxView> createState() => _MailboxInboxViewState();
}

class _MailboxInboxViewState extends State<MailboxInboxView> {
  String? _selectedId;
  bool _manualMode = false;

  /// Übernimmt die Antwort in den Zielvorgang. Liefert false, wenn der Anwalt
  /// die Übernahme im Konfliktdialog abgebrochen hat.
  Future<bool> _gemeinsamUebernehmen(
    ZentralrufReplyData daten,
    String? zielReferenz,
  ) async {
    // Antwort dem im Formular gewählten Vorgang zuordnen (Vorauswahl: der über
    // die Referenz gefundene Vorgang, Req. 3.3) und ihn auf „Beantwortet"
    // schalten — so bleiben mehrere offene Vorgänge sauber unterscheidbar, und
    // eine fehlgeschlagene Auto-Zuordnung lässt sich von Hand korrigieren.
    // [zielReferenz] == null bedeutet „Neuen Vorgang anlegen". Der Word-Assistent
    // wählt diesen Vorgang beim Wechsel auf den Tab automatisch vor und belegt
    // die Felder daraus (Phase 4).
    final vorgaenge = getIt<VorgangCubit>();

    // Widerspricht die Antwort bereits erfassten Vorgangsdaten, entscheidet
    // der Anwalt je Feld — statt den Antwortwert still zu verwerfen (Punkt 6).
    var antwortGewinnt = const <AntwortKonfliktFeld>{};
    final ziel = vorgaenge.zielVorgangFuer(daten, zielReferenz: zielReferenz);
    if (ziel != null) {
      final konflikte = AntwortKonflikte.finde(ziel, daten);
      if (konflikte.isNotEmpty) {
        final entscheidung = await AntwortKonfliktDialog.zeige(
          context,
          konflikte,
        );
        if (entscheidung == null || !mounted) return false;
        antwortGewinnt = entscheidung;
      }
    }

    vorgaenge.uebernehmeAntwort(
      daten,
      zielReferenz: zielReferenz,
      antwortGewinnt: antwortGewinnt,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vorgangsdaten übernommen. Passende Felder werden beim Ausfüllen der '
          'Vorlage automatisch vorbelegt.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.wordAutomation);
    return true;
  }

  Future<void> _treffferUebernehmen(
    ReceivedReply reply,
    ZentralrufReplyData daten,
    String? zielReferenz,
  ) async {
    final uebernommen = await _gemeinsamUebernehmen(daten, zielReferenz);
    if (!uebernommen || !mounted) return;
    // Mit der Übernahme gilt der erfasste Treffer als erledigt.
    context.read<MailboxInboxCubit>().acknowledge(reply.id);
    setState(() => _selectedId = null);
  }

  Future<void> _manuellUebernehmen(
    ZentralrufReplyData daten,
    String? zielReferenz,
  ) async {
    final uebernommen = await _gemeinsamUebernehmen(daten, zielReferenz);
    if (!uebernommen || !mounted) return;
    setState(() => _manualMode = false);
    context.read<ZentralrufReplyBloc>().add(const ResetZentralrufReplyEvent());
  }

  void _manuellOeffnen() {
    context.read<ZentralrufReplyBloc>().add(const ResetZentralrufReplyEvent());
    setState(() {
      _manualMode = true;
      _selectedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxInboxCubit, MailboxInboxState>(
      builder: (context, state) {
        final replies = state.replies;
        final selected = replies
            .where((reply) => reply.id == _selectedId)
            .firstOrNull;

        return Column(
          children: [
            MailboxStatusBanner(status: state.status, error: state.error),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 360,
                    child: MailboxReplyList(
                      replies: replies,
                      selectedId: _selectedId,
                      manualSelected: _manualMode,
                      loading: state.loading && replies.isEmpty,
                      status: state.status,
                      onSelect: (id) => setState(() {
                        _selectedId = id;
                        _manualMode = false;
                      }),
                      onManual: _manuellOeffnen,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: MailboxDetailPane(
                      manualMode: _manualMode,
                      selected: selected,
                      onTrefferUebernehmen: _treffferUebernehmen,
                      onManuellUebernehmen: _manuellUebernehmen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
