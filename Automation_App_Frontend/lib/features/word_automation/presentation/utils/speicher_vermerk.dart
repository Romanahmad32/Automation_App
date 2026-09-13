import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/services/schreiben_dateiname.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';

/// Hält am Vorgang fest, dass ein Schreiben **gespeichert** wurde (§4.6, §4.9).
///
/// Der eine Punkt, an dem [Vorgang.schreibenNummer] entsteht — beide
/// Speicherwege gehen hier durch: die Ablage in der Akte
/// (`schliesseAblageAb`, mit [dokumentPfad], [aktenOrdner] und
/// [status]) und das freie „an anderem Ort speichern"
/// (`DokumentManuellSpeichern`, ohne all das). Gespeichert ist gespeichert;
/// worauf der Anwalt die Datei legt, ändert an der Zählung nichts.
///
/// **Nicht beim Erzeugen** (#133): Vorher stand die Nummer schon nach dem
/// ersten Klick auf „Dokument erstellen" am Vorgang, und die Leiste über dem
/// Formular fragte „Korrektur oder neues Schreiben?" für ein Schreiben, das es
/// nirgends gab. Jetzt gilt: keine gespeicherte Fassung, keine Frage.
///
/// Festgehalten wird **jede** Speicherung, auch die zweite und jede weitere
/// (§4.6). Nur der Status läuft dabei ausschließlich vorwärts
/// ([VorgangStatus.vorwaertsAuf]) — ein versendeter Vorgang fällt nicht auf
/// „abgelegt" zurück, behält aber trotzdem Pfad, Ordner und Nummer der neuen
/// Fassung.
///
/// [vorgang] ist der **frischeste** Stand des Vorgangs (aus dem [vorgaenge]),
/// nicht die womöglich veraltete Kopie im Wizard: Von seiner bisherigen Nummer
/// aus wird gerechnet.
void vermerkeGespeichertesSchreiben({
  required VorgangCubit vorgaenge,
  required WizardCubit wizard,
  required Vorgang vorgang,
  String? dokumentPfad,
  String? aktenOrdner,
  VorgangStatus? status,
}) {
  final vermerkt = vorgang.copyWith(
    // `null` heißt in `copyWith` durchweg „unverändert" — beim freien Speichern
    // bleiben Status, Pfad und Aktenordner deshalb genau so stehen, wie sie
    // sind. Die Datei liegt dort, wo der Anwalt sie hinlegte, und nicht in der
    // Akte; sie zum Dokument des Vorgangs zu erklären, wäre geraten.
    status: status == null ? null : vorgang.status.vorwaertsAuf(status),
    dokumentPfad: dokumentPfad,
    aktenOrdner: aktenOrdner,
    schreibenNummer: naechsteSchreibenNummer(
      vorgang,
      neuesSchreiben: wizard.state.neuesSchreiben ?? false,
    ),
  );

  vorgaenge.aktualisiere(vermerkt);
  // Den gewählten Vorgang mitheben, sonst zeigte die Leiste über dem Formular
  // weiter den Stand von vor dem Speichern.
  wizard.uebernehmeVorgangsStand(vermerkt);
  // Mit der gespeicherten Fassung ist die Wahl verbraucht. Zurück auf „noch
  // nicht gewählt" und nicht auf „Korrektur": Wer das nächste Schreiben
  // beginnt, wird wieder gefragt (§4.9).
  wizard.setNeuesSchreiben(null);
}
