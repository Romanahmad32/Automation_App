import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Zeigt nach „Arbeitspaket holen", was der Anwalt jetzt in der Hand hat.
///
/// [pfad] ist die tatsächlich geschriebene Datei, [mandantenAnzahl] die Zahl
/// aus `ArbeitspaketBauen.mandantenAnzahl` — das Paket selbst zählt Ordner,
/// geschnitten wird aber nach Mandanten.
Future<void> zeigePaketGespeichert(
  BuildContext context, {
  required Arbeitspaket paket,
  required String pfad,
  required int mandantenAnzahl,
}) => showDialog<void>(
  context: context,
  builder: (_) => PaketGespeichertDialog(
    paket: paket,
    pfad: pfad,
    mandantenAnzahl: mandantenAnzahl,
  ),
);

/// Der Abschluss von „Arbeitspaket holen": eine Datei und ein Text, und was
/// wovon zu halten ist.
///
/// **Warum ein Dialog und keine Rückmeldung.** Vorher stand hier eine Zeile
/// über der Liste — „… gespeichert. Die Anleitung liegt in der Zwischenablage"
/// — die nach wenigen Sekunden verschwand. Genau in diesem Augenblick hält der
/// Anwalt zum einzigen Mal beides zugleich in der Hand, und genau hier kam die
/// Frage auf, warum es denn zweierlei gibt. Ein Tooltip auf der anderen Seite
/// kommt dafür zu spät, und eine Rückmeldung ist wieder weg, bevor jemand zum
/// Kanzleirechner gelaufen ist.
///
/// Die Zeile „steckt auch in der Paketdatei" ist kein Beiwerk: Sie nimmt der
/// Zwischenablage die Last, die einzige Kopie zu sein. Ein einziges Kopieren
/// unterwegs löscht sie, und ohne diesen Satz wäre der Auftrag damit
/// scheinbar verloren.
class PaketGespeichertDialog extends StatelessWidget {
  final Arbeitspaket paket;
  final String pfad;
  final int mandantenAnzahl;

  const PaketGespeichertDialog({
    super.key,
    required this.paket,
    required this.pfad,
    required this.mandantenAnzahl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.move_to_inbox_outlined, size: 40),
      title: Text('Paket ${paket.paket} gespeichert'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mandantenAnzahl Mandanten mit ${paket.ordner.length} Ordnern.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _zeile(
            context,
            icon: Icons.description_outlined,
            titel: paket.dateiname,
            rolle: 'Das ist die Arbeit — diese Datei geben Sie weiter.',
            knopf: 'Im Ordner zeigen',
            onDruck: () => DateiOeffner.zeigeImOrdner(pfad),
          ),
          const SizedBox(height: 16),
          _zeile(
            context,
            icon: Icons.content_paste_outlined,
            titel: 'Der Auftrag liegt in der Zwischenablage',
            rolle: 'Den schicken Sie voraus — er sagt, was zu tun ist.',
            knopf: 'Erneut kopieren',
            onDruck: () =>
                Clipboard.setData(ClipboardData(text: paket.anleitung)),
          ),
          const SizedBox(height: 20),
          Text(
            'Der Auftrag steckt auch in der Paketdatei selbst; verloren geht '
            'er nicht.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fertig'),
        ),
      ],
    );
  }

  /// Eine der beiden Rollen: was es ist, wozu es da ist, und der Griff dazu.
  Widget _zeile(
    BuildContext context, {
    required IconData icon,
    required String titel,
    required String rolle,
    required String knopf,
    required VoidCallback onDruck,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                rolle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              TextButton(onPressed: onDruck, child: Text(knopf)),
            ],
          ),
        ),
      ],
    );
  }
}
