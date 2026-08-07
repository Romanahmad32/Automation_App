import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_leer_hinweis.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_vorgang_zeile.dart';
import 'package:flutter/material.dart';

/// Karte „Offene Vorgänge": die dringendsten noch nicht abgeschlossenen
/// Vorgänge in der Reihenfolge, in der der Anwalt sie anfassen sollte
/// ([DashboardUebersicht]), jeweils mit dem Sprung zum nächsten Schritt.
class DashboardOffeneVorgaengeKarte extends StatelessWidget {
  final DashboardUebersicht uebersicht;

  const DashboardOffeneVorgaengeKarte({super.key, required this.uebersicht});

  @override
  Widget build(BuildContext context) {
    final vorgaenge = uebersicht.offeneVorgaenge;
    return DashboardKarte(
      titel: 'Offene Vorgänge',
      icon: Icons.folder_open_outlined,
      umfang: vorgaenge.length < uebersicht.anzahlOffen
          ? '${vorgaenge.length} von ${uebersicht.anzahlOffen}'
          : null,
      aktionLabel: 'Alle Vorgänge',
      zielTab: AppTabIndex.vorgaenge,
      child: vorgaenge.isEmpty
          ? const DashboardLeerHinweis(
              icon: Icons.task_alt,
              text:
                  'Kein Vorgang wartet auf eine Handlung. Neue Vorgänge '
                  'entstehen über „Vorgang starten".',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, vorgang) in vorgaenge.indexed) ...[
                  if (index > 0) const Divider(height: 1, indent: 16),
                  DashboardVorgangZeile(vorgang: vorgang),
                ],
              ],
            ),
    );
  }
}
