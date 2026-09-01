import 'package:automation_app/features/dev_simulation/presentation/widgets/simulation_menu.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_fehlende_daten_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_naechster_schritt.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_versand_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_warte_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/zeichen_text.dart';
import 'package:flutter/material.dart';

/// Eine Zeile in der Vorgänge-Verwaltung: Zeichen, Parteien und Status, der
/// statusabhängige „Nächster Schritt"-Sprung ([VorgangNaechsterSchritt]) samt
/// Warte-Hinweis bei lange offenen Anfragen sowie Aktionen zum Bearbeiten und
/// Löschen.
class VorgangVerwaltungTile extends StatelessWidget {
  final Vorgang vorgang;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VorgangVerwaltungTile({
    super.key,
    required this.vorgang,
    required this.onEdit,
    required this.onDelete,
  });

  String _untertitel() {
    final teile = <String>[
      // Die volle Referenz steht hier als Nebenzeile — oben trägt die Kachel
      // das Zeichen. Nur, wenn sie sich davon unterscheidet: sonst stünde
      // dieselbe Zeichenkette zweimal untereinander.
      if (vorgang.referenz != vorgang.zeichen) vorgang.referenz,
      if ((vorgang.unfallDatum ?? '').trim().isNotEmpty)
        'Unfall v. ${vorgang.unfallDatum!.trim()}',
      vorgang.rechtsgebiet.displayName,
    ];
    return teile.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parteien = vorgang.parteienBezeichnung;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: ZeichenText(
                          vorgang,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      VorgangStatusChip(status: vorgang.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (parteien.isNotEmpty)
                    Text(parteien, style: theme.textTheme.bodyMedium),
                  Text(
                    _untertitel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  VorgangVersandZeile(referenz: vorgang.referenz),
                  VorgangWarteHinweis(vorgang: vorgang),
                  VorgangFehlendeDatenHinweis(vorgang: vorgang),
                ],
              ),
            ),
            // Nur im Debug-Build sichtbar (Entwickler-Simulation).
            SimulationMenu(vorgang: vorgang),
            VorgangNaechsterSchritt(vorgang: vorgang),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Löschen',
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
