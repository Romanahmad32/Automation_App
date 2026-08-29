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

/// Ob dieser Betrag die Zeile rot macht. `null` (noch nichts oder Unlesbares
/// getippt) ist keine Beanstandung: Die Zeile wandert dann ohnehin nicht in die
/// Aufstellung, und wer gerade erst „-" getippt hat, wird nicht angeblafft.
bool betragUnzulaessig(double? betrag) => betrag != null && betrag < 0;

/// Ein fertiger Satz je unzulässiger Position, benannt nach ihrer Nummer in der
/// Aufstellung — dieselbe Nummer, die die Vorschau in der Spalte „Position"
/// zeigt und die im erzeugten Dokument steht. Leere Liste = alles zulässig.
List<String> schadenspositionenFehler(List<DamageItem> positionen) => [
  for (final (index, position) in positionen.indexed)
    if (betragUnzulaessig(position.amount))
      'Position ${index + 1} ("${position.description}"): '
          '$negativerBetragHinweis',
];
