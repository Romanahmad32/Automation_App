import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';

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

/// Eine Zeile des Formulars, so weit sie für die Prüfung zählt.
///
/// Der Rohtext steht **neben** dem gelesenen Betrag und nicht statt seiner: Ein
/// `betrag == null` allein sagt nicht, ob das Feld leer ist oder etwas
/// Unlesbares enthält — und genau daran hängt, ob die Zeile beanstandet wird.
/// Zusammengesetzt wird das Paar nur über [schadenspositionszeile], damit die
/// beiden nicht auseinanderlaufen können.
typedef Schadenspositionszeile = ({
  String bezeichnung,
  String betragText,
  double? betrag,
});

/// Eine Formularzeile aus ihren beiden Rohtexten.
Schadenspositionszeile schadenspositionszeile({
  required String bezeichnung,
  required String betragText,
}) => (
  bezeichnung: bezeichnung,
  betragText: betragText,
  betrag: betragAusEingabe(betragText),
);

/// Ob dieser Betrag die Zeile rot macht. `null` (noch nichts oder Unlesbares
/// getippt) ist für sich genommen keine Beanstandung — ob daraus eine wird,
/// entscheidet [betragFehler] anhand der ganzen Zeile.
///
/// `-0,0` ist **kein** Verstoß — es ist numerisch null. Damit trotzdem kein
/// `-0.0` in den Vertrag hinausgeht, normalisiert `betragAusEingabe` es.
bool betragUnzulaessig(double? betrag) => betrag != null && betrag < 0;

/// Die Beanstandung dieser Zeile, oder `null`. Beide Fälle enden gleich: Das
/// Feld wird rot und `schadensaufstellungIstErzeugbar` sperrt den Knopf.
///
/// Der zweite Fall ist der gefährlichere und der jüngere. Eine Zeile, deren
/// Betrag sich nicht lesen ließ, fiel bis hierher stillschweigend aus der
/// Aufstellung: Der Anwalt sah seine ausgefüllte Zeile im Formular stehen und
/// verschickte ein Anspruchsschreiben, dem diese Forderung fehlte.
///
/// Beanstandet wird erst, wenn die Zeile **gemeint** ist — Bezeichnung
/// vorhanden und im Betragsfeld steht etwas. Sonst blafft das Formular den
/// Anwalt beim Tippen an, und wer eine Markierung nach dem ersten Tastendruck
/// sieht, lernt sie zu übersehen. Die beiden Bedingungen sind bewusst am
/// Zustand festgemacht und nicht am Fokus: Das Verdikt über den Knopf muss auch
/// dann stimmen, wenn der Anwalt direkt aus dem Betragsfeld heraus auf
/// „Dokument erstellen" klickt und das Feld nie verlassen hat.
///
/// Die vorbelegten Standardpositionen (§4.4) bleiben damit unbeanstandet: Sie
/// tragen zwar eine Bezeichnung, ihr Betragsfeld ist aber leer.
String? betragFehler(Schadenspositionszeile zeile) {
  if (betragUnzulaessig(zeile.betrag)) return negativerBetragHinweis;
  if (zeile.betrag == null &&
      zeile.betragText.trim().isNotEmpty &&
      zeile.bezeichnung.trim().isNotEmpty) {
    return unlesbarerBetragHinweis(zeile.betragText);
  }
  return null;
}

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
    if (betragFehler(zeile) case final meldung?)
      'Position ${index + 1} '
          '(${zeile.bezeichnung.trim().isEmpty ? ohneBezeichnung : '"${zeile.bezeichnung.trim()}"'})'
          ': $meldung',
];

/// Dieselbe Prüfung für bereits erfasste Positionen — die gespeicherte
/// Aufstellung eines Vorgangs oder die Neuberechnung nach dem Vorsteuer-Wechsel,
/// wo es keine Rohtexte mehr gibt, sondern nur noch [DamageItem]s.
///
/// Der Rohtext wird hier aus dem Betrag zurückgeschrieben. Er ist damit
/// zwangsläufig lesbar — richtig so: Was einmal eine Zahl geworden ist, kann
/// nicht mehr unlesbar sein, und geprüft bleibt an dieser Stelle allein das
/// Vorzeichen.
List<String> positionenFehler(List<DamageItem> positionen) =>
    schadenspositionenFehler([
      for (final position in positionen)
        schadenspositionszeile(
          bezeichnung: position.description,
          betragText: betragAlsEingabe(position.amount),
        ),
    ]);
