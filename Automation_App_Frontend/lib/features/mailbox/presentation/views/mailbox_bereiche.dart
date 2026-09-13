import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/gesendet_view.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die beiden Bereiche des Postfach-Tabs.
enum MailboxBereich { posteingang, gesendet }

/// Der Umschalter über dem Postfach: **Posteingang** und **Gesendet** — beides
/// Ansichten auf dasselbe Postfach, deshalb ein `SegmentedButton`
/// (`auswahl_themes.dart`: Segment = Ansicht/Reiter).
///
/// Der frühere dritte Bereich „Zentralruf-Antworten" ist entfallen (Issue
/// #134): Eine erfasste Antwort ist keine eigene Gattung Post, sondern eine
/// Zeile des Posteingangs, die die App bereits ausgewertet hat — sie wird dort
/// als solche gekennzeichnet und öffnet statt des Mailtexts das
/// Vorgangsdaten-Formular. Zwei Listen derselben Nachrichten nebeneinander
/// hießen, den Anwalt raten zu lassen, in welcher er suchen muss.
class MailboxBereiche extends StatefulWidget {
  const MailboxBereiche({super.key});

  @override
  State<MailboxBereiche> createState() => _MailboxBereicheState();
}

class _MailboxBereicheState extends State<MailboxBereiche> {
  final MailboxAuswahlSignal _signal = getIt<MailboxAuswahlSignal>();
  MailboxBereich _bereich = MailboxBereich.posteingang;

  @override
  void initState() {
    super.initState();
    _signal.pendingReplyId.addListener(_zeigePosteingang);
  }

  /// Vom Dashboard angetippter Treffer: Er liegt im Posteingang, also muss
  /// dieser Bereich vorn sein. Welche Zeile geöffnet wird, entscheidet
  /// [PosteingangView] anhand desselben Signals.
  void _zeigePosteingang() {
    if (_signal.pendingReplyId.value == null) return;
    if (_bereich == MailboxBereich.posteingang) return;
    setState(() => _bereich = MailboxBereich.posteingang);
  }

  @override
  void dispose() {
    _signal.pendingReplyId.removeListener(_zeigePosteingang);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SegmentedButton<MailboxBereich>(
          segments: const [
            ButtonSegment(
              value: MailboxBereich.posteingang,
              label: Text('Posteingang'),
              icon: Icon(Icons.inbox_outlined),
            ),
            ButtonSegment(
              value: MailboxBereich.gesendet,
              label: Text('Gesendet'),
              icon: Icon(Icons.send_outlined),
            ),
          ],
          selected: {_bereich},
          onSelectionChanged: (wahl) => setState(() => _bereich = wahl.first),
        ),
      ),
      Expanded(child: _inhalt()),
    ],
  );

  Widget _inhalt() => switch (_bereich) {
    MailboxBereich.posteingang => BlocProvider(
      create: (_) => getIt<PosteingangCubit>()..aktualisieren(),
      child: const PosteingangView(),
    ),
    MailboxBereich.gesendet => BlocProvider(
      create: (_) => getIt<GesendetCubit>()..laden(),
      child: const GesendetView(),
    ),
  };
}
