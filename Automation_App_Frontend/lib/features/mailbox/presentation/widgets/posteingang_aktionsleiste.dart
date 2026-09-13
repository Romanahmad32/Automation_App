import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Die drei Handgriffe an einer geöffneten Posteingangsnachricht (§4.3) — und
/// **nur** diese drei: kein Zitieren, kein Weiterleiten (REQUIREMENTS §8).
///
/// Bewusst ohne eigenes Verhalten: Was hinter den drei Handlungen steckt
/// (Versanddialog, Ablage-Dialog), entscheidet die Stelle, die diese Leiste
/// zusammenbaut (`posteingang_detail.dart`) — sie kennt weder `AblageCubit`
/// noch `EmailEntwurfCubit`. [eintrag]/[inhalt]/[vorgang] dienen allein den
/// Tooltips, damit jeder Knopf sagt, *woran* er wirkt.
///
/// **Antworten** ist der einzige gefüllte Knopf: Es ist der Handgriff, den
/// der Anwalt an einer eingegangenen Nachricht am häufigsten braucht. Ein
/// `Wrap` statt einer `Row` lässt die Leiste bei schmaler Breite umbrechen,
/// statt seitlich überzulaufen.
class PosteingangAktionsleiste extends StatelessWidget {
  const PosteingangAktionsleiste({
    super.key,
    required this.eintrag,
    required this.inhalt,
    this.vorgang,
    required this.onAntworten,
    required this.onMailInDieAkte,
    required this.onMailBeimVersand,
  });

  final PosteingangEintrag eintrag;
  final PosteingangInhalt? inhalt;
  final Vorgang? vorgang;
  final VoidCallback onAntworten, onMailInDieAkte, onMailBeimVersand;

  /// Die Adresse, an die „Antworten" schreiben würde — für den Tooltip; die
  /// eigentliche Vorbelegung des Versanddialogs baut die aufrufende Stelle.
  String get _absender =>
      inhalt?.absenderAdresse ?? eintrag.absenderAdresse ?? eintrag.absender;

  /// Gemeinsamer, kompakter Zuschnitt für alle drei Knöpfe — eine
  /// Aktionsleiste über dem Nachrichtentext soll nicht so hoch bauen wie ein
  /// Formularknopf.
  static const _stil = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: 'Öffnet den Versanddialog mit „$_absender" als Empfänger',
          child: FilledButton.icon(
            style: _stil,
            onPressed: onAntworten,
            icon: const Icon(Icons.reply, size: 18),
            label: const Text('Antworten'),
          ),
        ),
        Tooltip(
          message: vorgang == null
              ? 'Legt die Nachricht in einer Akte ab'
              : 'Legt die Nachricht in der Akte zu ${vorgang!.zeichen} ab',
          child: OutlinedButton.icon(
            style: _stil,
            onPressed: onMailInDieAkte,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: const Text('In die Akte'),
          ),
        ),
        Tooltip(
          message: 'Nimmt die Nachricht als Anhang in den nächsten Versand auf',
          child: OutlinedButton.icon(
            style: _stil,
            onPressed: onMailBeimVersand,
            icon: const Icon(Icons.outgoing_mail, size: 18),
            label: const Text('Beim Versand verwenden'),
          ),
        ),
      ],
    );
  }
}
