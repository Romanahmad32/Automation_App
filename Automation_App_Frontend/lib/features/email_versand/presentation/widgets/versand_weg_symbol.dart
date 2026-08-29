import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:flutter/material.dart';

/// Das Zeichen vor einem Versandeintrag (§4.8).
///
/// Der grüne Haken steht **nur** beim Direktversand: Nur dort hat die App die
/// Einlieferung gesehen. Eine Übergabe an Outlook trägt das Postausgangszeichen
/// — ein Protokoll, das beides gleich aussehen lässt, wäre als Nachweis
/// schlechter als keines.
///
/// Eigener Baustein, weil zwei Zeilen denselben Eintrag zeigen: die schmale in
/// der Vorgangsliste (`VorgangVersandZeile`) und die ausführliche im
/// Protokollfenster (`VersandEintragZeile`). Sie unterscheiden sich in der
/// Größe — die Regel dahinter darf sich nicht unterscheiden, und zweimal
/// gebaut täte sie es beim nächsten Anfassen.
class VersandWegSymbol extends StatelessWidget {
  final VersandWeg weg;

  /// Kantenlänge des Symbols: 20 im Protokollfenster, 14 in der Vorgangsliste,
  /// wo die Zeile unter dem Vorgang mitläuft.
  final double groesse;

  const VersandWegSymbol({super.key, required this.weg, this.groesse = 20});

  @override
  Widget build(BuildContext context) {
    final nachweis = weg.istNachweis;

    return Icon(
      nachweis ? Icons.check_circle : Icons.outbox_outlined,
      size: groesse,
      color: nachweis ? Colors.green : Theme.of(context).colorScheme.outline,
    );
  }
}
