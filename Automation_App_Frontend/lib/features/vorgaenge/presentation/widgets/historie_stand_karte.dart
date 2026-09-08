import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/jahrgang_stand_chip.dart';
import 'package:flutter/material.dart';

/// Die Karte „Historie" über der Filterleiste des Registers (§6.2): Woher das
/// übernommene Registerbuch reicht, welche Jahrgänge fehlen und wo Lücken
/// offen blieben — plus die zwei Wege, daran etwas zu ändern.
///
/// Sie steht **über** der Tabelle und nicht in den Einstellungen: Der Anwalt
/// soll sehen, dass 2021 fehlt, während er im Register blättert — und nicht
/// erst, wenn er danach sucht.
class HistorieStandKarte extends StatelessWidget {
  final RegisterHistorieStand stand;

  /// Öffnet die Import-Seite. Als Rückruf und nicht als Route hier drin, damit
  /// die Karte für sich testbar bleibt.
  final VoidCallback? onDateiEinlesen;

  /// Führt zur Anleitung für den Erzeuger der Importdatei — sie liegt auf
  /// derselben Seite, es gibt keinen zweiten Dialog dafür.
  final VoidCallback? onAnleitung;

  /// Klick auf einen Jahrgangs-Chip: setzt den Jahrgangsfilter darunter.
  final ValueChanged<int>? onJahrgang;

  /// Der vierstellige Jahrgang, auf dem der Filter gerade steht — der Chip
  /// dazu wird hervorgehoben. Null heißt: kein Jahrgangsfilter.
  final String? gewaehlterJahrgang;

  const HistorieStandKarte({
    super.key,
    required this.stand,
    this.onDateiEinlesen,
    this.onAnleitung,
    this.onJahrgang,
    this.gewaehlterJahrgang,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _kopf(theme),
          if (_jahrgaenge().isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _chips()),
          ],
        ],
      ),
    );
  }

  Widget _kopf(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.history_edu_outlined,
            size: 19,
            color: scheme.onPrimaryContainer,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Historie', style: theme.textTheme.titleMedium),
              Text(
                _untertitel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAnleitung,
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('Anleitung'),
        ),
        OutlinedButton.icon(
          onPressed: onDateiEinlesen,
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('Datei einlesen…'),
        ),
      ],
    );
  }

  /// Kein festes Startjahr: Wie weit das Registerbuch zurückreicht, sagt der
  /// Bestand und nicht eine Zahl im Code.
  String _untertitel() {
    final kleinster = stand.kleinsterJahrgang;
    if (kleinster == null) return 'noch keine Historie übernommen';
    return 'ab $kleinster';
  }

  /// Übernommene und fehlende Jahrgänge in einer Folge, aufsteigend — die
  /// Lücke soll zwischen ihren Nachbarn stehen und nicht am Ende.
  List<int> _jahrgaenge() {
    final jahre = <int>{
      ...stand.jahrgaenge.map((eintrag) => eintrag.jahrgang),
      ...stand.fehlendeJahrgaenge,
    }.toList();
    jahre.sort();
    return jahre;
  }

  List<Widget> _chips() => [
    for (final jahrgang in _jahrgaenge())
      JahrgangStandChip(
        jahrgang: jahrgang,
        stand: stand.zuJahrgang(jahrgang),
        ausgewaehlt: gewaehlterJahrgang == '$jahrgang',
        onTap: onJahrgang == null ? null : () => onJahrgang!(jahrgang),
      ),
  ];
}
