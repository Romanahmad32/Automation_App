import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_handgriffe.dart';
import 'package:automation_app/features/mailbox/presentation/utils/zentralruf_uebernahme.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zentralruf_detail.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_hervorhebung_signal.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die rechte Seite des Posteingangs: entweder die Nachricht selbst
/// ([PosteingangDetail]) oder — wenn zu ihr bereits eine Zentralruf-Antwort
/// erfasst ist — deren Formular ([PosteingangZentralrufDetail]).
///
/// Diese Weiche ist der Kern der Variante B (Issue #134): Der frühere eigene
/// Bereich „Zentralruf-Antworten" entfällt, weil eine erfasste Antwort nichts
/// anderes ist als eine Zeile des Posteingangs, die die App schon gelesen hat.
/// „Mail anzeigen" schaltet für genau diese Zeile auf die Mailansicht um; die
/// Umschaltung lebt lokal hier, weil sie nur für die geöffnete Nachricht gilt
/// und beim Öffnen der nächsten wieder verfallen soll.
class PosteingangDetailBereich extends StatefulWidget {
  const PosteingangDetailBereich({
    super.key,
    required this.state,
    required this.antworten,
  });

  final PosteingangState state;

  /// Die noch offenen, automatisch erfassten Zentralruf-Antworten aus
  /// `MailboxInboxCubit` — verknüpft über `mailSchluessel` ↔ `messageId`.
  final List<ReceivedReply> antworten;

  @override
  State<PosteingangDetailBereich> createState() =>
      _PosteingangDetailBereichState();
}

class _PosteingangDetailBereichState extends State<PosteingangDetailBereich> {
  final Set<String> _mailStattZentralruf = {};

  ReceivedReply? _antwortZu(PosteingangEintrag eintrag) {
    final schluessel = normalisiereMailSchluessel(eintrag.messageId);
    if (schluessel == null) return null;
    for (final antwort in widget.antworten) {
      if (normalisiereMailSchluessel(antwort.mailSchluessel) == schluessel) {
        return antwort;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eintrag = widget.state.auswahl;
    if (eintrag == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Eine Nachricht auswählen, um sie zu lesen, zu beantworten oder '
            'in der Akte abzulegen.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final antwort = _antwortZu(eintrag);
    if (antwort != null && !_mailStattZentralruf.contains(eintrag.id)) {
      return PosteingangZentralrufDetail(
        antwort: antwort,
        onUebernehmen: _uebernehmen,
        onMailAnzeigen: () =>
            setState(() => _mailStattZentralruf.add(eintrag.id)),
      );
    }
    return _mailDetail(eintrag);
  }

  Widget _mailDetail(PosteingangEintrag eintrag) {
    final state = widget.state;
    final cubit = context.read<PosteingangCubit>();
    final griffe = PosteingangHandgriffe(cubit);
    final bezug = state.bezugFuer(eintrag.id);
    final vorgang = bezug?.vorgang;

    return PosteingangDetail(
      key: ValueKey(eintrag.id),
      eintrag: eintrag,
      inhalt: state.inhalt,
      inhaltLaedt: state.inhaltLaedt,
      inhaltFehler: state.inhaltFehler,
      onErneutVersuchen: () => cubit.oeffnen(eintrag),
      bezug: bezug,
      onZumVorgang: () => _zumVorgang(vorgang),
      onNichtZuordnen: () => cubit.nichtZuordnen(eintrag.id),
      onAntworten: () => griffe.antworten(
        context,
        eintrag,
        inhalt: state.inhalt,
        vorgang: vorgang,
      ),
      onMailInDieAkte: () =>
          griffe.mailInDieAkte(context, eintrag, vorgang: vorgang),
      onMailBeimVersand: () =>
          griffe.mailBeimVersand(context, eintrag, vorgang: vorgang),
      onAnhangOeffnen: (anhang) =>
          griffe.anhangOeffnen(context, eintrag.id, anhang),
      onAnhangInDieAkte: (anhang) =>
          griffe.anhangInDieAkte(context, eintrag.id, anhang, vorgang: vorgang),
      onAnhangBeimVersand: (anhang) => griffe.anhangBeimVersand(
        context,
        eintrag.id,
        anhang,
        vorgang: vorgang,
      ),
      ladenderAnhangId: state.ladenderAnhangId,
    );
  }

  /// Sprung in die Vorgangsverwaltung: das Hervorhebungssignal setzen und den
  /// Tab wechseln — die Liste scrollt dort hin und hebt die Zeile hervor.
  void _zumVorgang(Vorgang? vorgang) {
    if (vorgang == null) return;
    getIt<VorgangHervorhebungSignal>().setze(vorgang.referenz);
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.vorgaenge);
  }

  /// Übernimmt die erfasste Antwort in den Vorgang, quittiert den Treffer und
  /// wechselt zum Word-Assistenten — derselbe Ablauf wie früher in
  /// `MailboxInboxView._treffferUebernehmen`.
  Future<void> _uebernehmen(
    ReceivedReply antwort,
    ZentralrufReplyData daten,
    String? zielReferenz,
  ) async {
    final uebernommen = await uebernimmZentralrufDaten(
      context,
      daten,
      zielReferenz: zielReferenz,
    );
    if (!uebernommen || !mounted) return;
    // Mit der Übernahme gilt der erfasste Treffer als erledigt; die Zeile im
    // Posteingang bleibt und trägt fortan „Zentralruf · übernommen".
    context.read<MailboxInboxCubit>().acknowledge(antwort.id);
    context.read<PosteingangCubit>().schliessen();
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.wordAutomation);
  }
}
