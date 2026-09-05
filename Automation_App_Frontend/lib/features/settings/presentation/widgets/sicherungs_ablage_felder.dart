import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:automation_app/features/settings/presentation/widgets/synchronisierter_ordner_vorschlag.dart';
import 'package:flutter/material.dart';

/// Der Ordner, in den die App beim Beenden selbsttätig eine Sicherung legt
/// (§7.2) — und aus dem der zweite Arbeitsplatz den Stand beim Öffnen anbietet.
///
/// Wie bei der Register-Ablage ist es ein ganz gewöhnlicher Ordner; dass
/// dahinter OneDrive steht, weiß die App nicht. Der erkannte Pfad steht deshalb
/// nur als *Vorschlag* da: Er spart das Suchen im Dialog, mehr nicht.
class SicherungsAblageFelder extends StatelessWidget {
  const SicherungsAblageFelder({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OrdnerAuswahlFeld(
        formControlName: 'sicherungsAblageOrdner',
        beschriftung: 'Sicherungsablage',
        dialogTitel: 'Ordner für die automatischen Sicherungen wählen',
        icon: Icons.backup_outlined,
        hinweisOhneOrdner:
            'Ohne eigene Wahl sichert die App unter den Ordner für die '
            'App-Daten. Fehlt auch der, sichert sie nur auf Knopfdruck.',
      ),
      SizedBox(height: 8),
      SynchronisierterOrdnerVorschlag(
        formControlName: 'sicherungsAblageOrdner',
        unterordner: SynchronisierterOrdner.sicherungenUnterordner,
      ),
    ],
  );
}
