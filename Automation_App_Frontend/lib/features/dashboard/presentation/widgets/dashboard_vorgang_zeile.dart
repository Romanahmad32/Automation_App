import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_fehlende_daten_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_naechster_schritt.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_warte_hinweis.dart';
import 'package:flutter/material.dart';

/// Eine Zeile der Karte „Offene Vorgänge": Referenz, Parteien und Status, dazu
/// die bestehenden Hinweise auf lange Wartezeit bzw. fehlende Daten und der
/// statusabhängige Sprung zur Weiterbearbeitung ([VorgangNaechsterSchritt]).
/// Bewusst schlanker als die [VorgangVerwaltungTile] der Vorgangsverwaltung —
/// bearbeitet und gelöscht wird dort, nicht auf der Startseite.
class DashboardVorgangZeile extends StatelessWidget {
  final Vorgang vorgang;

  const DashboardVorgangZeile({super.key, required this.vorgang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parteien = vorgang.parteienBezeichnung;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vorgang.referenz,
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
                const SizedBox(height: 2),
                Text(
                  parteien.isEmpty
                      ? 'Az. ${vorgang.aktenzeichen}'
                      : '$parteien  ·  Az. ${vorgang.aktenzeichen}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                VorgangWarteHinweis(vorgang: vorgang),
                VorgangFehlendeDatenHinweis(vorgang: vorgang),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VorgangNaechsterSchritt(vorgang: vorgang),
        ],
      ),
    );
  }
}
