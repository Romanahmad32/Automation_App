import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_aktionsleiste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_aktionen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_liste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_ansicht_umschalter.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail_kopf.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_html_ansicht.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_text_ansicht.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_vorschlag_karte.dart';
import 'package:flutter/material.dart';

/// Die Hülle der Detailansicht (Issue #134): Kopf → Vorschlagskarte (nur wenn
/// [bezug] gesetzt ist) → Aktionsleiste → Ansicht-Umschalter → Text/HTML →
/// Anhänge — in einer gerundeten, scrollbaren Fläche.
///
/// **Wer den Bezug unterdrückt, entscheidet der Aufrufer:** [bezug] ist genau
/// dann `null`, wenn kein Vorgang erkannt wurde **oder** der Anwalt zuvor
/// „Nicht zuordnen" gedrückt hat (§4.3, nur für die Sitzung gemerkt). Diese
/// Hülle prüft nur noch, ob ein Wert da ist.
///
/// Die formatierte/Text-Umschaltung ist reine Anzeigesache dieser einen
/// Nachricht und lebt deshalb lokal in diesem Widget statt im gemeinsamen
/// Zustand: Sie hat keine Bedeutung außerhalb der geöffneten Nachricht und
/// springt beim Öffnen der nächsten wieder auf „Formatiert" zurück.
class PosteingangDetail extends StatefulWidget {
  const PosteingangDetail({
    super.key,
    required this.eintrag,
    this.inhalt,
    this.inhaltLaedt = false,
    this.inhaltFehler,
    required this.onErneutVersuchen,
    this.bezug,
    required this.onZumVorgang,
    required this.onNichtZuordnen,
    required this.onAntworten,
    required this.onMailInDieAkte,
    required this.onMailBeimVersand,
    required this.onAnhangOeffnen,
    required this.onAnhangInDieAkte,
    required this.onAnhangBeimVersand,
    this.anhangLaedt = false,
  });

  final PosteingangEintrag eintrag;

  /// Der geladene Inhalt — `null` solange er noch nicht (erneut) geladen ist.
  final PosteingangInhalt? inhalt;
  final bool inhaltLaedt;
  final String? inhaltFehler;
  final VoidCallback onErneutVersuchen;

  /// Der Vorgangsbezug für die Vorschlagskarte, bereits um „Nicht zuordnen"
  /// bereinigt — `null` blendet die Karte aus.
  final Vorgangsbezug? bezug;
  final VoidCallback onZumVorgang;
  final VoidCallback onNichtZuordnen;

  final VoidCallback onAntworten;
  final VoidCallback onMailInDieAkte;
  final VoidCallback onMailBeimVersand;

  final Future<void> Function(PosteingangAnhang) onAnhangOeffnen;
  final Future<void> Function(PosteingangAnhang) onAnhangInDieAkte;
  final Future<void> Function(PosteingangAnhang) onAnhangBeimVersand;

  /// True, während ein Anhang oder die `.eml` gerade ins Zwischenlager
  /// geholt wird — siehe die Begründung an `PosteingangAnhangZeile`.
  final bool anhangLaedt;

  @override
  State<PosteingangDetail> createState() => _PosteingangDetailState();
}

class _PosteingangDetailState extends State<PosteingangDetail> {
  final ScrollController _lauf = ScrollController();
  bool _formatiert = true;

  @override
  void didUpdateWidget(PosteingangDetail alt) {
    super.didUpdateWidget(alt);
    if (alt.eintrag.id != widget.eintrag.id) {
      _formatiert = true;
    }
  }

  @override
  void dispose() {
    _lauf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inhalt = widget.inhalt;
    final bezug = widget.bezug;
    final aktionen = PosteingangAnhangAktionen(
      onOeffnen: widget.onAnhangOeffnen,
      onInDieAkte: widget.onAnhangInDieAkte,
      onBeimVersand: widget.onAnhangBeimVersand,
      laeuft: widget.anhangLaedt,
    );

    return GerundeterKasten(
      farbe: theme.colorScheme.surface,
      randfarbe: theme.colorScheme.outlineVariant,
      rundung: 16,
      child: Scrollbar(
        controller: _lauf,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _lauf,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosteingangDetailKopf(eintrag: widget.eintrag, inhalt: inhalt),
              if (bezug != null) ...[
                const SizedBox(height: 16),
                PosteingangVorschlagKarte(
                  bezug: bezug,
                  onZumVorgang: widget.onZumVorgang,
                  onNichtZuordnen: widget.onNichtZuordnen,
                ),
              ],
              const SizedBox(height: 16),
              PosteingangAktionsleiste(
                eintrag: widget.eintrag,
                inhalt: inhalt,
                vorgang: bezug?.vorgang,
                onAntworten: widget.onAntworten,
                onMailInDieAkte: widget.onMailInDieAkte,
                onMailBeimVersand: widget.onMailBeimVersand,
              ),
              const Divider(height: 32),
              if (widget.inhaltLaedt) const LinearProgressIndicator(),
              if (widget.inhaltFehler != null) ...[
                Text(widget.inhaltFehler!),
                TextButton(
                  onPressed: widget.onErneutVersuchen,
                  child: const Text('Erneut versuchen'),
                ),
              ],
              if (inhalt != null) ...[
                if (inhalt.hatHtml) ...[
                  PosteingangAnsichtUmschalter(
                    formatiert: _formatiert,
                    onChanged: (wert) => setState(() => _formatiert = wert),
                  ),
                  const SizedBox(height: 12),
                ],
                if (inhalt.hatHtml && _formatiert)
                  PosteingangHtmlAnsicht(
                    html: inhalt.html!,
                    bilderBlockiert: inhalt.bilderBlockiert,
                  )
                else
                  PosteingangTextAnsicht(
                    text: inhalt.text,
                    gekuerzt: inhalt.gekuerzt,
                  ),
                if (inhalt.anhaenge.isNotEmpty) ...[
                  const Divider(height: 32),
                  PosteingangAnhangListe(
                    anhaenge: inhalt.anhaenge,
                    aktionen: aktionen,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
