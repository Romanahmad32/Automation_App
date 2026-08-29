import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_uebersicht_dialog.dart';
import 'package:flutter/material.dart';

/// Was beim Speichern des Vorgangs mit dem Mandanten geschehen soll — das
/// Ergebnis der Übersichts-Rückfrage (§1.3), fertig für `SpeichereVorgangEvent`.
///
/// Höchstens eines von [neuerMandant]/[aktualisierterMandant] ist gesetzt; sind
/// beide null, ist am Mandanten nichts zu tun. [bestaetigt] trennt „nichts zu
/// tun" von „der Anwalt hat die Übersicht abgebrochen" — im zweiten Fall darf
/// auch der Vorgang nicht gespeichert werden.
class MandantEntscheidung {
  final CreateMandantRequest? neuerMandant;
  final Mandant? aktualisierterMandant;
  final bool bestaetigt;

  const MandantEntscheidung({
    this.neuerMandant,
    this.aktualisierterMandant,
    this.bestaetigt = true,
  });

  /// Die Übersicht wurde abgebrochen — nichts speichern.
  static const abgebrochen = MandantEntscheidung(bestaetigt: false);

  /// Am Mandanten ist nichts neu oder geändert; es gab keine Rückfrage.
  static const ohneAenderung = MandantEntscheidung();

  /// Fragt die Übersicht ab, falls aus [daten] gegenüber [gewaehlt] eine Anlage
  /// oder Änderung entstünde, und liefert, was der Bloc tun soll.
  ///
  /// Der Karten-Knopf (`MandantSpeichernButton`) stellt dieselbe Frage, gibt
  /// aber nur die [MandantAenderungsart] zurück, weil er den Mandanten allein
  /// speichert. Hier wird daraus gleich die Nutzlast des Speicher-Events.
  static Future<MandantEntscheidung> hole(
    BuildContext context, {
    required VorgangStartenDaten daten,
    required Mandant? gewaehlt,
  }) async {
    final art = mandantAenderungsart(daten, gewaehlt);
    if (art == MandantAenderungsart.keine) return ohneAenderung;

    final istNeu = art == MandantAenderungsart.neu;
    final bestaetigt = await MandantUebersichtDialog.zeige(
      context,
      istNeu: istNeu,
      zeilen: istNeu ? mandantNeuFelder(daten) : mandantDiff(daten, gewaehlt!),
    );
    if (bestaetigt != true) return abgebrochen;

    return istNeu
        ? MandantEntscheidung(neuerMandant: daten.toCreateRequest())
        : MandantEntscheidung(aktualisierterMandant: daten.applyTo(gewaehlt!));
  }
}
