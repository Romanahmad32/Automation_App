import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:flutter/material.dart';

/// Eine Zeile Klartext zu **einem** Ordner: welcher gilt und warum.
///
/// Nach dem Muster der `SicherungsStandZeile` im Reiter „Datensicherung" —
/// eine Auskunft, die der Anwalt lesen kann, statt eines Pfads, den er deuten
/// muss. Der Anlass ist derselbe: Ein Ordner, der auf diesem Rechner nicht
/// auflösbar ist, fällt sonst erst auf, wenn eine Datei nicht dort landet, wo
/// sie erwartet wurde (#103).
///
/// Rein anzeigend und ohne eigenen Ladeweg — damit derselbe Satz im Test
/// nachlesbar ist, ohne Dienst und ohne `getIt`.
class OrdnerZustandZeile extends StatelessWidget {
  final OrdnerZustand zustand;

  const OrdnerZustandZeile({super.key, required this.zustand});

  /// Der Feldname des Vertrags in der Sprache des Reiters. Unbekannte Namen
  /// bleiben stehen, wie sie sind: Ein neuer Ordner im Dienst soll hier
  /// auftauchen und nicht verschwinden.
  static String beschriftung(String feld) => switch (feld) {
    'appDatenOrdner' => 'Ordner für die App-Daten',
    'aktenStammordner' => 'Akten-Stammordner',
    'vorlagenOrdner' => 'Vorlagen',
    'registerAblageOrdner' => 'Register-Ablage',
    'sicherungsAblageOrdner' => 'Sicherungsablage',
    _ => feld,
  };

  /// Der Satz zu einem Zustand. Der Anker steht im Fehlerfall ausdrücklich
  /// mit Namen da: „nicht auflösbar" allein sagt dem Anwalt nicht, dass sein
  /// Geschäfts-OneDrive auf diesem Rechner fehlt.
  static String satz(OrdnerZustand zustand) => switch (zustand.zustand) {
    OrdnerZustandArten.ankerFehlt =>
      'OneDrive-Konto „${zustand.anker}" ist auf diesem Rechner nicht '
          'vorhanden — der Ordner lässt sich hier nicht auflösen.',
    OrdnerZustandArten.ordnerFehlt =>
      '${zustand.wirksam} — Ordner wird beim ersten Schreiben angelegt.',
    OrdnerZustandArten.abgeleitet =>
      '${zustand.wirksam} — abgeleitet aus dem Ordner für die App-Daten.',
    OrdnerZustandArten.standard =>
      '${zustand.wirksam} — die App verwaltet die Vorlagen selbst.',
    OrdnerZustandArten.bereit => zustand.wirksam,
    OrdnerZustandArten.nichtGesetzt =>
      'Nicht festgelegt — hier legt die App nichts ab.',
    _ => zustand.wirksam,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = '${beschriftung(zustand.feld)}: ${satz(zustand)}';

    // Nur der fehlende Anker ist ein Befund, auf den jemand reagieren soll.
    // Alles andere ist Auskunft und bekommt deshalb die stille Zeile — sonst
    // stünden fünf rote Symbole da, von denen vier nichts bedeuten.
    if (zustand.stoert) return FehlerHinweis(nachricht: text);

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}
