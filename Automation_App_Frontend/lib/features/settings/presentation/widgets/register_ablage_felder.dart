import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:automation_app/features/settings/presentation/widgets/synchronisierter_ordner_vorschlag.dart';
import 'package:flutter/material.dart';

/// **Wohin** der Register-Spiegel geschrieben wird (§6.2) — eine der drei
/// abweichenden Ordnerwahlen im Aufklapper. Leer heißt seit #103 nicht mehr
/// „kein Spiegel", sondern „unter dem Ordner für die App-Daten"; erst ohne
/// beides bleibt die Datei aus.
///
/// Der Ablageordner ist ein gewöhnlicher Ordner. Liegt er im synchronisierten
/// Bereich, ist das Register unterwegs lesbar — die App selbst weiß davon
/// nichts. Genau deshalb steht der OneDrive-Pfad hier nur als *Vorschlag*: Er
/// spart das Suchen im Dialog, mehr nicht.
///
/// Name, Zeitpunkt und Inhalt der Datei stehen daneben in
/// `register_spiegel_felder.dart`: Das sind Einstellungen des Registers, keine
/// Ordnerwahl, und sie gehören deshalb nicht in einen zugeklappten Aufklapper.
class RegisterAblageFelder extends StatelessWidget {
  const RegisterAblageFelder({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OrdnerAuswahlFeld(
        formControlName: 'registerAblageOrdner',
        beschriftung: 'Register-Ablage',
        dialogTitel: 'Ordner für das Register wählen',
        icon: Icons.cloud_outlined,
        hinweisOhneOrdner:
            'Ohne eigene Wahl entsteht das Register unter dem Ordner für die '
            'App-Daten. Fehlt auch der, wird keine Register-Datei geschrieben.',
      ),
      SizedBox(height: 8),
      SynchronisierterOrdnerVorschlag(
        formControlName: 'registerAblageOrdner',
        unterordner: SynchronisierterOrdner.registerUnterordner,
      ),
    ],
  );
}
