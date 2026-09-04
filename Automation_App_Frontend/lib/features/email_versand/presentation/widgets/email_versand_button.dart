import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_dialog.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';

/// Öffnet den Mail-Entwurf (§4.7) und meldet das Ergebnis zurück. Der eine
/// Einstieg für alle Stellen, an denen gesendet wird — heute der Word-Assistent
/// und das Postfach.
///
/// Alle Angaben kommen als Parameter herein und werden **nicht** aus dem
/// Kontext gelesen: Der Knopf steht auch in einem Dialog, und dessen Kontext
/// hängt am Navigator-Overlay, nicht mehr an den Blocs der Seite.
class EmailVersandButton extends StatelessWidget {
  final Vorgang? vorgang;

  /// Überschreibt den Mandanten; sonst löst der Cubit ihn aus dem Vorgang auf.
  final Mandant? mandant;

  /// Eine noch nicht übernommene Zentralruf-Antwort (Postfach).
  final ZentralrufReplyData? antwort;

  final List<String> anhangVorauswahl;
  final List<String> ausDerAkte;

  /// Ermittelt die Anhänge erst beim Öffnen und schlägt dann die beiden Listen
  /// oben. Für Aufrufer, die dafür den Fall-Ordner lesen müssen: Beim Bauen
  /// wäre das ein Verzeichnislauf je Neubau — und beim Öffnen ist der Stand
  /// ohnehin der frischere, etwa wenn nebenher noch ein Gutachten dazukam.
  final ({List<String> vorauswahl, List<String> ausDerAkte}) Function()?
  anhaengeErmitteln;

  /// Ergebnis eines bereits erfolgten Versands; färbt die Beschriftung um,
  /// damit ein zweiter Versand als solcher erkennbar ist.
  final EmailVersandErgebnis? bereitsVersendet;

  final ValueChanged<EmailVersandErgebnis>? onVersendet;

  final String beschriftung;
  final String beschriftungErneut;

  const EmailVersandButton({
    super.key,
    this.vorgang,
    this.mandant,
    this.antwort,
    this.anhangVorauswahl = const [],
    this.ausDerAkte = const [],
    this.anhaengeErmitteln,
    this.bereitsVersendet,
    this.onVersendet,
    this.beschriftung = 'E-Mail verfassen und senden',
    this.beschriftungErneut = 'Weitere E-Mail verfassen',
  });

  Future<void> _oeffnen(BuildContext context) async {
    final anhaenge = anhaengeErmitteln?.call();
    final ergebnis = await EmailVersandDialog.zeigen(
      context,
      vorgang: vorgang,
      mandant: mandant,
      antwort: antwort,
      anhangVorauswahl: anhaenge?.vorauswahl ?? anhangVorauswahl,
      ausDerAkte: anhaenge?.ausDerAkte ?? ausDerAkte,
    );
    if (ergebnis == null) return;

    onVersendet?.call(ergebnis);
    if (!context.mounted) return;
    final text =
        'E-Mail an ${ergebnis.empfaenger.length} Empfänger versendet.'
        '${ergebnis.imGesendetOrdner ? '' : ' ${ergebnis.hinweis ?? ''}'}';
    final nebenbefund =
        !ergebnis.imGesendetOrdner && (ergebnis.hinweis?.isNotEmpty ?? false);
    if (nebenbefund) {
      // Der Nebenbefund ist eine Handlungsanweisung, kein reiner Erfolg —
      // deshalb länger stehen als drei Sekunden.
      Rueckmeldung.zeigeHinweis(
        context,
        text,
        dauer: const Duration(seconds: 6),
      );
    } else {
      Rueckmeldung.zeigeErfolg(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final erneut = bereitsVersendet != null;

    return OutlinedButton.icon(
      onPressed: () => _oeffnen(context),
      icon: Icon(erneut ? Icons.forward_to_inbox : Icons.outgoing_mail),
      label: Text(erneut ? beschriftungErneut : beschriftung),
    );
  }
}
