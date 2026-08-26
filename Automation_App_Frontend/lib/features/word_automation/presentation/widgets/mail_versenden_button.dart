import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_button.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/utils/mail_anhaenge.dart';
import 'package:flutter/material.dart';

/// Der Sendeknopf des Word-Assistenten (§4.7). Er unterscheidet sich vom
/// allgemeinen [EmailVersandButton] nur darin, dass er die Anhänge kennt: das
/// abgelegte Schreiben als PDF, dazu die übrigen Dateien des Fall-Ordners.
///
/// Steht an zwei Stellen — im Speicherschritt für sich (senden, ohne den
/// Vorgang abzuschließen) und im Abschlussdialog.
class MailVersendenButton extends StatelessWidget {
  final Vorgang? vorgang;
  final Mandant? mandant;
  final EmailVersandErgebnis? bereitsVersendet;
  final ValueChanged<EmailVersandErgebnis> onVersendet;

  const MailVersendenButton({
    super.key,
    required this.onVersendet,
    this.vorgang,
    this.mandant,
    this.bereitsVersendet,
  });

  @override
  Widget build(BuildContext context) {
    return EmailVersandButton(
      vorgang: vorgang,
      mandant: mandant,
      // Erst beim Öffnen, nicht beim Bauen: `zu` läuft durch den Fall-Ordner,
      // und dieser Knopf hängt in Abschnitten, die bei jeder Zustandsänderung
      // neu bauen. Nebenbei ist der Stand so der frischere — wer das Gutachten
      // gerade erst in den Ordner gelegt hat, findet es im Dialog wieder.
      anhaengeErmitteln: () => MailAnhangAuswahl.zu(vorgang?.dokumentPfad),
      bereitsVersendet: bereitsVersendet,
      onVersendet: onVersendet,
    );
  }
}
