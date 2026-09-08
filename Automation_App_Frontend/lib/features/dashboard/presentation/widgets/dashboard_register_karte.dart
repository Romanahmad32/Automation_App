import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_leer_hinweis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';

/// Karte „Sachgebiete-Register": die zuletzt entstandenen Registerzeilen im
/// selben Spaltenschema wie die Registerseite (Lfd. Nr. | Zeichen | Sache ·
/// Sachbestand | Rechtsgebiet) — der Anwalt sieht auf der Startseite, wo die
/// laufende Auftragsnummer gerade steht.
///
/// Die Zeilen baut die Karte aus dem bereits geladenen Vorgangsbestand
/// ([RegisterZeile.ausVorgang]) statt aus dem Zeilen-Endpunkt: Die Startseite
/// zeigt nur die letzten fünf **Vorgänge** der App und keine Historie, und ein
/// zusätzlicher Abruf beim Öffnen der Startseite wäre dafür zu teuer. Die
/// Registerseite selbst nimmt die Backend-Zeilen — sie ist die Ansicht, die mit
/// der Kanzleidatei übereinstimmen muss.
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
          : RegisterTabelle(
              zeilen: [
                for (final vorgang in zeilen) RegisterZeile.ausVorgang(vorgang),
              ],
              kompakt: true,
            ),
    );
  }
}
