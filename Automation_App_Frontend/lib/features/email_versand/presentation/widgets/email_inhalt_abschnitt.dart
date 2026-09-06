import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/betreff_text_felder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_vorschau.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/geschlecht_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/grussformel_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/handarbeit_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/mail_vorlagen_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_uebersicht.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_abschnitt.dart';
import 'package:flutter/material.dart';

/// Der zweite Abschnitt des Versandformulars: **was in der Mail steht** (§4.7).
///
/// Die Reihenfolge ist die des Textes, den sie erzeugt: erst die Vorlage (sie
/// schreibt Betreff und Text), dann Anredeart → Anrede → Zusatzgruß (die erste
/// beugt die zweite, die zweite steht über der dritten), dann was die
/// Platzhalter ergeben haben — und darunter die Felder, in denen das alles
/// zusammenkommt.
///
/// **Ohne die Platzhalterhilfe** (entfernt am 06.09.2026): Die volle,
/// offene Liste aller Platzhalter gehört ins Schreiben einer *Vorlage*
/// (`MailVorlageDialog`) — beim Verfassen einer einzelnen, schon gefüllten
/// Mail wird sie fast nie gebraucht und kostete hier nur Platz.
/// [PlatzhalterUebersicht] bleibt: Sie zeigt, wenn nötig, was offen blieb.
///
/// **Anrede und Gruß gehören hierher und nicht nach oben zum Vorgang**
/// (entschieden am 06.09.2026): Sie sind Textbausteine dieser einen Mail, keine
/// Angabe über den Fall. Über dem Nachrichtenfeld stehend, sind sie neben dem
/// zu sehen, was sie ändern.
class EmailInhaltAbschnitt extends StatelessWidget {
  final EmailEntwurfState state;

  /// Betreff und Text samt der Frage, welches von beiden ein Platzhalter-Klick
  /// trifft. Gehalten wird es im Formular darüber — beide Felder überleben
  /// jeden Neubau dieses Abschnitts.
  final PlatzhalterEinfuegeZiel ziel;

  /// Zeigt die hinterlegte Signatur unter dem Nachrichtenfeld. Aus, sobald die
  /// Vorschau daneben steht — dort ist sie ohnehin im vollen Text zu sehen.
  final bool mitSignaturVorschau;

  final bool aktiv;

  const EmailInhaltAbschnitt({
    super.key,
    required this.state,
    required this.ziel,
    required this.aktiv,
    this.mitSignaturVorschau = true,
  });

  @override
  Widget build(BuildContext context) {
    return VersandAbschnitt(
      symbol: Icons.subject,
      titel: 'Inhalt',
      untertitel:
          'Vorlage, Anrede und Gruß schreiben Betreff und Text — beides bleibt '
          'danach von Hand änderbar.',
      children: [
        const MailVorlagenAuswahl(),
        // Über den Chipreihen, weil er von ihnen handelt: Was sie noch tun,
        // sobald der Text von Hand bearbeitet ist (§4.7).
        const HandarbeitHinweis(),
        const GeschlechtAuswahl(),
        const AnredeAuswahl(),
        const GrussformelAuswahl(),
        const PlatzhalterUebersicht(),
        BetreffTextFelder(
          ziel: ziel,
          aktiv: aktiv,
          betreffFehler: state.markiert.betreffFehler,
          minZeilen: mitSignaturVorschau ? 8 : 10,
          maxZeilen: 16,
        ),
        if (mitSignaturVorschau)
          EmailSignaturVorschau(
            signatur: state.bereitschaft?.signatur ?? '',
            html: state.bereitschaft?.signaturHtml ?? '',
            bilder: state.bereitschaft?.signaturBilder ?? const [],
            weggelassen: state.entwurf.ohneSignaturBilder,
          ),
      ],
    );
  }
}
