import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_bezug_quelle.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_detail_bereich.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_manuelle_antwort_dialog.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_werkzeugleiste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_liste.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Posteingang (§4.3, Variante B zu Issue #134): Werkzeugleiste, links die
/// Liste, rechts die geöffnete Nachricht.
///
/// Ab [nebeneinanderAb] stehen Liste und Detail nebeneinander; darunter zeigt
/// die Ansicht nur die Liste und legt die geöffnete Nachricht als Vollbild
/// darüber (Zurück-Pfeil oben links). Eine schmale Spalte neben einer schmalen
/// Spalte macht beide unlesbar — dieselbe Überlegung wie im abgelösten
/// `MailboxListUndPanel`, nur mit einer Ebene statt gestapelter Hälften: Eine
/// Mail ist zum Lesen da und verträgt keine halbe Fensterhöhe.
///
/// Die Ansicht hält selbst keinen Zustand über die Nachrichten; sie verdrahtet
/// nur: Nach jeder Seitenladung und bei jeder Änderung am Vorgangsbestand
/// rechnet sie die Vorgangsbezüge neu, und aus den erfassten
/// Zentralruf-Antworten merkt sie sich, welche Zeilen bereits ausgewertet sind.
class PosteingangView extends StatefulWidget {
  const PosteingangView({super.key});

  /// Ab dieser Breite stehen Liste ([listenbreite]) und Detail (dann noch
  /// mindestens 420 px breit, wie im Entwurf gefordert) nebeneinander.
  static const double nebeneinanderAb = 1080;
  static const double listenbreite = 400;

  @override
  State<PosteingangView> createState() => _PosteingangViewState();
}

class _PosteingangViewState extends State<PosteingangView> {
  final PosteingangBezugQuelle _bezugQuelle = PosteingangBezugQuelle();
  final MailboxAuswahlSignal _auswahlSignal = getIt<MailboxAuswahlSignal>();
  StreamSubscription<void>? _vorgangsAbo;
  Timer? _rueckfall;

  @override
  void initState() {
    super.initState();
    // Auch ohne eingeschalteten Monitor oder SignalR werden neue Mails
    // sichtbar. Nur die erste Seite ohne geöffneten Text wird nachgeladen.
    _rueckfall = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final cubit = context.read<PosteingangCubit>();
      if (!cubit.state.laedt &&
          cubit.state.seitennummer == 1 &&
          cubit.state.auswahl == null) {
        cubit.aktualisieren();
      }
    });
    // Ein neu angelegter oder geänderter Vorgang kann eine längst geladene
    // Zeile erst zuordnungsfähig machen — deshalb bei jeder Änderung neu.
    _vorgangsAbo = getIt<VorgangCubit>().stream.listen((_) => _bezuege());
    _auswahlSignal.pendingReplyId.addListener(_pruefeAuswahlSignal);
    _bezugQuelle.ladeMandanten().then((_) => _bezuege());
    // Der Bloc der Seite kann seine Treffer schon haben (Rückkehr aus dem
    // Bereich „Gesendet"), dann feuert der Listener unten nicht mehr.
    _merkeZentralruf(context.read<MailboxInboxCubit>().state);
  }

  @override
  void dispose() {
    _auswahlSignal.pendingReplyId.removeListener(_pruefeAuswahlSignal);
    _vorgangsAbo?.cancel();
    _rueckfall?.cancel();
    super.dispose();
  }

  void _bezuege() {
    if (!mounted) return;
    context.read<PosteingangCubit>().bezuegeNeuRechnen(_bezugQuelle.erkenner());
  }

  void _merkeZentralruf(MailboxInboxState state) {
    context.read<PosteingangCubit>().merkeZentralruf(
      state.replies.map((antwort) => antwort.mailSchluessel ?? ''),
    );
  }

  /// Der vom Dashboard angetippte Treffer: seine Mail im Posteingang suchen
  /// und öffnen — das Detail zeigt dann von selbst das Zentralruf-Formular.
  /// Solange keine Zeile geladen ist, bleibt das Signal stehen und wird nach
  /// der ersten Seite erneut geprüft.
  void _pruefeAuswahlSignal() {
    final replyId = _auswahlSignal.pendingReplyId.value;
    if (replyId == null || !mounted) return;
    final cubit = context.read<PosteingangCubit>();
    if (cubit.state.eintraege.isEmpty) return;
    _auswahlSignal.loesche();

    final antwort = context
        .read<MailboxInboxCubit>()
        .state
        .replies
        .where((eintrag) => eintrag.id == replyId)
        .firstOrNull;
    final schluessel = normalisiereMailSchluessel(antwort?.mailSchluessel);
    if (schluessel == null) return;
    final treffer = cubit.state.eintraege
        .where((e) => normalisiereMailSchluessel(e.messageId) == schluessel)
        .firstOrNull;
    if (treffer != null) cubit.oeffnen(treffer);
  }

  Future<void> _manuellEinfuegen() async {
    final uebernommen = await MailboxManuelleAntwortDialog.zeigen(context);
    if (!uebernommen || !mounted) return;
    // Der Vorgangsbestand hat sich geändert — die Liste kann jetzt mehr
    // zuordnen als vorher.
    _bezuege();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PosteingangCubit, PosteingangState>(
          listenWhen: (alt, neu) => alt.eintraege != neu.eintraege,
          listener: (_, _) {
            _bezuege();
            _pruefeAuswahlSignal();
          },
        ),
        BlocListener<MailboxInboxCubit, MailboxInboxState>(
          listenWhen: (alt, neu) => alt.replies != neu.replies,
          listener: (_, neu) => _merkeZentralruf(neu),
        ),
      ],
      child: BlocBuilder<PosteingangCubit, PosteingangState>(
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final breit =
                constraints.maxWidth >= PosteingangView.nebeneinanderAb;
            if (!breit && state.auswahl != null) return _vollbild(state);
            return Column(
              children: [
                _werkzeugleiste(context, state),
                const Divider(height: 1),
                Expanded(
                  child: breit
                      ? _nebeneinander(state)
                      : PosteingangListe(state: state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _werkzeugleiste(BuildContext context, PosteingangState state) {
    final cubit = context.read<PosteingangCubit>();
    return MailboxWerkzeugleiste(
      filter: state.filter,
      zentralrufAnzahl: state.zentralrufAnzahl,
      onFilter: cubit.setzeFilter,
      onNeuLaden: cubit.aktualisieren,
      onManuellEinfuegen: _manuellEinfuegen,
    );
  }

  Widget _nebeneinander(PosteingangState state) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: PosteingangView.listenbreite,
        child: PosteingangListe(state: state),
      ),
      const VerticalDivider(width: 1),
      Expanded(child: _detailFlaeche(state)),
    ],
  );

  /// Die geöffnete Nachricht auf voller Fläche, mit Zurück-Pfeil und Betreff
  /// als Kopfzeile — die schmale Fassung (Artboard 7 der Freigabe).
  Widget _vollbild(PosteingangState state) => Column(
    children: [
      Row(
        children: [
          IconButton(
            onPressed: context.read<PosteingangCubit>().schliessen,
            tooltip: 'Zurück zur Liste',
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              state.auswahl!.betreff,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      const Divider(height: 1),
      Expanded(child: _detailFlaeche(state)),
    ],
  );

  Widget _detailFlaeche(PosteingangState state) => Padding(
    padding: const EdgeInsets.all(12),
    child: PosteingangDetailBereich(
      state: state,
      antworten: context.watch<MailboxInboxCubit>().state.replies,
    ),
  );
}
