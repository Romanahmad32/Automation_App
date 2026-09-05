import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/presentation/widgets/abweichende_ordner_aufklapper.dart';
import 'package:automation_app/features/settings/presentation/widgets/app_daten_ordner_feld.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_zustand_liste.dart';
import 'package:automation_app/features/settings/presentation/widgets/stammordner_field.dart';
import 'package:flutter/material.dart';

/// **Alle** Ordner der App an einer Stelle (#103) — vorher standen sie zu
/// viert über zwei Spalten verteilt, jeder in einer eigenen Karte, und wer die
/// App einrichtete, musste selbst wissen, welcher wozu gehört.
///
/// Die Reihenfolge ist die Reihenfolge der Entscheidungen:
///
/// 1. **Der Ordner für die App-Daten** — die eine Wahl, die im Regelfall
///    genügt. Darunter entstehen Vorlagen, Register und Sicherungen.
/// 2. **Der Akten-Stammordner** — die zweite Wahl, und ausdrücklich eine
///    eigene: Er zeigt auf die gewachsene Ablage der Kanzlei (§6.1), die
///    nicht unter einen neuen App-Ordner gehört.
/// 3. **Der Aufklapper** für den Sonderfall, dass Vorlagen, Register oder
///    Sicherungen woanders liegen sollen.
/// 4. **Der Zustandsfuß**: was der Dienst mit alldem tatsächlich macht.
class OrdnerSektion extends StatelessWidget {
  const OrdnerSektion({super.key});

  @override
  Widget build(BuildContext context) => const FormSection(
    icon: Icons.folder_copy_outlined,
    title: 'Ordner',
    subtitle:
        'Ein Ordner für alles, was die App selbst ablegt — Vorlagen, '
        'Register und Sicherungen entstehen darunter beim ersten Schreiben. '
        'Daneben die Akten der Kanzlei, die dort bleiben, wo sie gewachsen '
        'sind. Liegt der Ordner in OneDrive, steht auf einem zweiten '
        'Arbeitsplatz alles von selbst richtig.',
    children: [
      AppDatenOrdnerFeld(),
      StammordnerField(),
      AbweichendeOrdnerAufklapper(),
      OrdnerZustandListe(),
    ],
  );
}
