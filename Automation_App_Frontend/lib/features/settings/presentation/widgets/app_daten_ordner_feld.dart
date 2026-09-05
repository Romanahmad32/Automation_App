import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:automation_app/features/settings/presentation/widgets/synchronisierter_ordner_vorschlag.dart';
import 'package:flutter/material.dart';

/// Die **eine** Ordnerwahl der App (#103): Darunter entstehen beim ersten
/// Schreiben `Vorlagen`, `Register` und `Sicherungen`.
///
/// Vorher waren es vier Wahlen in vier Dialogen, und der Anwalt musste selbst
/// wissen, welcher Ordner wozu gehört. Der Ort war dabei längst entschieden —
/// er liegt in OneDrive, nur die App wusste es viermal nicht. Deshalb steht
/// hier der erkannte Ordner als Vorschlag: ein Klick statt vier Dialoge.
///
/// Gesetzt wird er trotzdem nie von selbst (§1.3). Und die App spricht mit
/// keiner Cloud — sie liest die Umgebungsvariablen des OneDrive-Clients und
/// legt gewöhnliche Dateien ab.
class AppDatenOrdnerFeld extends StatelessWidget {
  const AppDatenOrdnerFeld({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OrdnerAuswahlFeld(
        formControlName: 'appDatenOrdner',
        beschriftung: 'Ordner für die App-Daten',
        dialogTitel: 'Ordner für die App-Daten wählen',
        icon: Icons.folder_copy_outlined,
        hinweisOhneOrdner:
            'Ohne diesen Ordner gilt allein, was unten unter „Abweichende '
            'Ordner festlegen" steht: Die Vorlagen verwaltet dann die App '
            'selbst, Register und Sicherung bleiben aus.',
      ),
      SizedBox(height: 8),
      SynchronisierterOrdnerVorschlag(
        formControlName: 'appDatenOrdner',
        unterordner: SynchronisierterOrdner.appDatenUnterordner,
        hinweisOhneVorschlag:
            'Auf diesem Rechner ist kein synchronisierter OneDrive-Ordner '
            'erkennbar. Der Ordner lässt sich trotzdem wählen — er kommt dann '
            'aber nicht von selbst auf einem zweiten Arbeitsplatz an.',
      ),
    ],
  );
}
