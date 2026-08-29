import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';

/// Was an einer Schadensposition unzulässig sein kann — geprüft im Formular,
/// bevor daraus ein Dokument entsteht.
///
/// Warum hier und nicht erst im Dienst: Die Modellvalidierung des Backends
/// antwortet mit einem HTTP 400, das keine Zeile benennt. Der Anwalt sieht dann
/// eine Fehlermeldung über einer Aufstellung, die plausibel aussieht, und muss
/// selbst suchen, welche der acht Positionen gemeint ist. Die Prüfung steht
/// deshalb dort, wo die Eingabe entsteht; die Schranke im Backend
/// (`DamageItemDto.Amount`) bleibt das Netz dahinter.
///
/// `0,00` ist **kein** Fehler: eine Position, die im Schreiben stehen soll, aber
/// noch nicht beziffert ist.

/// Der Satz an der Zeile selbst — kurz, weil er unter einem Eingabefeld steht.
const String negativerBetragHinweis = 'Betrag darf nicht negativ sein';

/// Wie eine Zeile benannt wird, die noch keine Bezeichnung trägt.
const String ohneBezeichnung = 'ohne Bezeichnung';

/// Eine Zeile des Formulars, so weit sie für die Prüfung zählt. `betrag` ist
/// `null`, solange nichts Lesbares dasteht.
typedef Schadenspositionszeile = ({String bezeichnung, double? betrag});

/// Ob dieser Betrag die Zeile rot macht. `null` (noch nichts oder Unlesbares
/// getippt) ist keine Beanstandung: Die Zeile wandert dann ohnehin nicht in die
/// Aufstellung, und wer gerade erst „-" getippt hat, wird nicht angeblafft.
///
/// `-0,0` ist **kein** Verstoß — es ist numerisch null. Damit trotzdem kein
/// `-0.0` in den Vertrag hinausgeht, normalisiert das Formular es beim Lesen.
bool betragUnzulaessig(double? betrag) => betrag != null && betrag < 0;

/// Ein fertiger Satz je unzulässiger Zeile, benannt nach ihrer Stelle im
/// **Formular** — von oben gezählt, so wie der Anwalt sie sieht.
///
/// Bewusst über die Formularzeilen und nicht über die fertige [DamageListing]:
/// Eine Zeile ohne Bezeichnung wandert nicht in die Aufstellung. Zählte man
/// dort, bliebe eine Zeile mit `-250` und leerer Bezeichnung ungezählt — das
/// Feld wäre sichtbar rot, „Dokument erstellen" trotzdem frei, und der Anwalt
/// erzeugte das Schreiben im Glauben, die Position sei drin.
List<String> schadenspositionenFehler(List<Schadenspositionszeile> zeilen) => [
  for (final (index, zeile) in zeilen.indexed)
    if (betragUnzulaessig(zeile.betrag))
      'Position ${index + 1} '
          '(${zeile.bezeichnung.trim().isEmpty ? ohneBezeichnung : '"${zeile.bezeichnung.trim()}"'})'
          ': $negativerBetragHinweis',
];

/// Dieselbe Prüfung für bereits erfasste Positionen — die gespeicherte
/// Aufstellung eines Vorgangs oder die Neuberechnung nach dem Vorsteuer-Wechsel,
/// wo es keine Rohtexte mehr gibt, sondern nur noch [DamageItem]s.
List<String> positionenFehler(List<DamageItem> positionen) =>
    schadenspositionenFehler([
      for (final position in positionen)
        (bezeichnung: position.description, betrag: position.amount),
    ]);
