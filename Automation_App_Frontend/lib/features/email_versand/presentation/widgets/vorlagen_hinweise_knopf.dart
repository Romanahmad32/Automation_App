import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/vorlagen_pruefung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagen_hinweise.dart';
import 'package:flutter/material.dart';

/// Der „?"-Knopf oben im Vorlageneditor: Er hält die Mängel- und
/// Beugungsauskunft (`VorlagenHinweise`) in einem Aufklappfenster bereit
/// (§4.7, geändert am 06.09.2026).
///
/// **Nur die Hülle ist neu.** Gerechnet wird unverändert in
/// [VorlagenPruefung]; gezeigt wird unverändert [VorlagenHinweise]. Was sich
/// ändert, ist der Platz: Der Block stand fest zwischen Nachrichtenfeld und
/// Platzhalterhilfe und schob letztere bei drei Mängeln aus dem Fenster —
/// ausgerechnet die Liste, die die Mängel behebt. Ein Hinweis, der die Abhilfe
/// verdrängt, arbeitet gegen sich selbst.
///
/// Das **Abzeichen** am Knopf ist der Ersatz für die verlorene Dauerpräsenz:
/// Wie viele Platzhalter nichts liefern, steht daran, ohne dass jemand klickt.
class VorlagenHinweiseKnopf extends StatelessWidget {
  final TextEditingController betreff;
  final TextEditingController text;

  const VorlagenHinweiseKnopf({
    super.key,
    required this.betreff,
    required this.text,
  });

  /// Was der Knopf verspricht — mit Zahl, sobald es etwas zu beanstanden gibt.
  /// Öffentlich, weil ein Test darauf zeigt.
  static String tooltipFuer(int maengel) => maengel == 0
      ? 'Platzhalter und Beugungen dieser Vorlage'
      : VorlagenMaengelListe.titelFuer(maengel);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([betreff, text]),
      builder: (context, _) {
        final vorlage = MailVorlage(betreff: betreff.text, text: text.text);
        final maengel = VorlagenPruefung.maengel(vorlage).length;

        return MenuAnchor(
          menuChildren: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    maengel == 0 && VorlagenPruefung.beugungen(vorlage).isEmpty
                    ? Text(
                        'Alle Platzhalter dieser Vorlage lösen auf, und es '
                        'sind keine Beugungen darin.',
                        style: theme.textTheme.bodySmall,
                      )
                    : VorlagenHinweise(betreff: betreff, text: text),
              ),
            ),
          ],
          builder: (context, steuerung, _) => IconButton(
            tooltip: tooltipFuer(maengel),
            onPressed: () =>
                steuerung.isOpen ? steuerung.close() : steuerung.open(),
            icon: Badge(
              isLabelVisible: maengel > 0,
              label: Text('$maengel'),
              child: const Icon(Icons.help_outline),
            ),
          ),
        );
      },
    );
  }
}
