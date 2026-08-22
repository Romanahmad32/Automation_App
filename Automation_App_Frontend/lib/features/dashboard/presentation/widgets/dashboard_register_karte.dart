import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_leer_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';

/// Karte „Sachgebiete-Register": die zuletzt entstandenen Registerzeilen im
/// selben Spaltenschema wie die Registerseite (laufende Nr. | Aktenzeichen |
/// Name ./. Gegner + Sachverhalt | Rechtsgebiet) — der Anwalt sieht auf der
/// Startseite, wo die laufende Auftragsnummer gerade steht.
class DashboardRegisterKarte extends StatelessWidget {
  final DashboardUebersicht uebersicht;

  const DashboardRegisterKarte({super.key, required this.uebersicht});

  @override
  Widget build(BuildContext context) {
    final zeilen = uebersicht.registerZeilen;

    return DashboardKarte(
      titel: 'Register (letzte Zeilen)',
      icon: Icons.table_chart_outlined,
      umfang: zeilen.length < uebersicht.registerGesamt
          ? '${zeilen.length} von ${uebersicht.registerGesamt}'
          : null,
      aktionLabel: 'Zum Register',
      zielTab: AppTabIndex.register,
      child: zeilen.isEmpty
          ? const DashboardLeerHinweis(
              icon: Icons.table_chart_outlined,
              text:
                  'Noch keine abgeschlossenen Vorgänge. Mit dem Abschluss '
                  'eines Vorgangs entsteht hier die nächste Registerzeile.',
            )
          : RegisterTabelle(zeilen: zeilen, kompakt: true),
    );
  }
}
