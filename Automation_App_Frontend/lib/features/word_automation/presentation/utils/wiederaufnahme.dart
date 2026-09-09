import 'dart:io';

import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';

/// Einen angefangenen Vorgang dort fortsetzen, wo er stand (§3).
///
/// Der Wizard hielt sein Dokument nur im Speicher: Nach einem Neustart waren
/// „Dokument begutachten" und „Speichern & weiter" gesperrt, obwohl am Vorgang
/// ein Schreiben vermerkt war. Die Absprünge „Prüfen & ablegen" und „Versenden
/// & abschließen" landeten damit auf Schritt 1 — sie versprachen einen Schritt,
/// den der Wizard nicht ausführen konnte.
///
/// Hier steht, woran das hängt: ob es ein benutzbares Schreiben gibt, und
/// welcher Schritt zum Stand des Vorgangs gehört.

/// Ob ein **anderer Vorgang** gewählt wurde — nicht bloss ein neuer Stand
/// desselben.
///
/// Der Unterschied ist der Riegel vor einem Datenverlust: Nach dem Erzeugen
/// hebt `uebernehmeVorgangsStand` die Auswahl auf den aktualisierten Vorgang
/// (jetzt mit `dokumentPfad`). Wer darauf mit „Dokument neu laden" reagiert,
/// ersetzt das eben erzeugte Dokument samt seinen Warnungen durch eine
/// wiederhergestellte Fassung ohne sie.
bool andererVorgang(Vorgang? vorher, Vorgang? jetzt) {
  if (vorher == null || jetzt == null) return vorher != jetzt;
  return !Vorgang.gleicheReferenz(vorher.referenz, jetzt.referenz);
}

/// Der Pfad des am Vorgang vermerkten Schreibens — oder `null`, wenn keiner
/// vermerkt ist oder die Datei nicht mehr dort liegt (verschoben, oder der
/// Arbeitsordner wurde nach dem Abschluss geräumt, §4.8).
String? wiederaufnehmbaresDokument(Vorgang? vorgang) {
  final pfad = vorgang?.dokumentPfad?.trim() ?? '';
  if (pfad.isEmpty) return null;
  return File(pfad).existsSync() ? pfad : null;
}

/// Der Wizard-Schritt, in dem ein Vorgang weitergeht — dieselbe Zuordnung, die
/// `VorgangNaechsterSchritt` auf seinen Knopf schreibt:
///
/// - **Erstellt** → begutachten und ablegen,
/// - **Abgelegt** → versenden und abschließen.
///
/// `null` heisst „kein Sprung": Vor dem ersten Schreiben (angefragt,
/// beantwortet) beginnt die Arbeit ohnehin beim Ausfüllen, und ein
/// abgeschlossener Vorgang (versendet) hat keinen nächsten Schritt mehr. Auch
/// ohne benutzbares Dokument wird nicht gesprungen — ein Sprung auf einen
/// gesperrten Schritt wäre nur eine andere Sackgasse.
WizardStep? wiederaufnahmeSchritt(Vorgang? vorgang) {
  if (vorgang == null || wiederaufnehmbaresDokument(vorgang) == null) {
    return null;
  }
  return switch (vorgang.status) {
    VorgangStatus.erstellt => WizardStep.review,
    VorgangStatus.abgelegt => WizardStep.save,
    VorgangStatus.angefragt ||
    VorgangStatus.beantwortet ||
    VorgangStatus.versendet => null,
  };
}
