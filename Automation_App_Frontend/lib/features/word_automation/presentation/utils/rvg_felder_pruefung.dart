/// Was an den drei Feldern unter der Positionsliste unzulässig sein kann:
/// Gebührensatz, „Geschäftsgebühr überschreiben", „Auslagenpauschale
/// überschreiben".
///
/// Dieselbe Begründung wie bei `schadenspositionen_pruefung.dart` — nur für die
/// Felder, die keine Zeile der Aufstellung sind: Die Schranken im Backend
/// (`DamageListingDto`) antworten mit einem HTTP 400, das kein Feld benennt.
/// Der Anwalt sah bisher eine allgemeine Störung über einer Aufstellung, die
/// plausibel aussieht, und nichts war markiert.
///
/// Der schärfste Fall ist die `0` im Gebührensatz: `betragAusEingabe("0")`
/// liefert `0.0` und nicht `null`, der Rückfall auf 1,3 griff also **nicht** —
/// und `gebuehrensatz: 0` ging still hinaus.
library;

import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';

/// Was das Backend prüft (`DamageListingDto.Gebuehrensatz`, `[Range(0.1, 10)]`).
/// Hier gespiegelt, nicht neu erfunden: Wer die Grenze dort ändert, ändert sie
/// hier mit — sonst meldet das Formular etwas anderes als der Dienst.
const double gebuehrensatzMinimum = 0.1;
const double gebuehrensatzMaximum = 10;

/// Der Satz, auf den ein **leeres** Feld zurückfällt (§ 13 RVG, Nr. 2300 VV).
const double gebuehrensatzVorgabe = 1.3;

/// Obergrenze der beiden Korrekturfelder — dieselbe wie beim Betrag je Position
/// (`DamageListingDto`, `[Range(0.0, 10_000_000.0)]`).
const double korrekturbetragMaximum = 10000000;

/// Die Sätze an der Zeile selbst — kurz, weil sie unter einem Eingabefeld
/// stehen. Sie nennen die Grenze, damit das Feld nicht nur „ungültig" sagt.
const String gebuehrensatzBereichHinweis =
    'Gebührensatz muss zwischen 0,1 und 10 liegen';
const String gebuehrensatzUnlesbarHinweis =
    'Gebührensatz nicht lesbar — leer lassen für 1,3';
const String negativerKorrekturbetragHinweis = 'Betrag darf nicht negativ sein';
const String zuGrosserKorrekturbetragHinweis =
    'Betrag darf höchstens 10.000.000 € betragen';

/// Wie die drei Felder in der Sammelmeldung über dem Knopf heißen — wörtlich
/// wie ihr `labelText` im Formular, sonst sucht der Anwalt ein Feld, das so
/// nicht dasteht.
const String gebuehrensatzFeldName = 'Gebührensatz';
const String geschaeftsgebuehrFeldName = 'Geschäftsgebühr überschreiben';
const String auslagenpauschaleFeldName = 'Auslagenpauschale überschreiben';

/// Ob dieser Gebührensatz das Feld rot macht — geprüft am **Rohtext**, weil
/// sein leerer Zustand eine eigene Bedeutung hat (Rückfall auf 1,3) und sich
/// deshalb nicht am gelesenen Wert unterscheiden lässt.
///
/// Unlesbar zählt hier als Verstoß, anders als beim Betrag je Position: Dort
/// ist Unlesbares der Normalzustand während des Tippens, hier nicht. Eine
/// gültige Eingabe kommt nie durch einen unlesbaren Zwischenstand — `1`, `1,`
/// und `1,3` lesen sich alle. Ohne diese Prüfung ginge stattdessen still 1,3
/// hinaus, obwohl etwas anderes im Feld steht.
String? gebuehrensatzFehler(String text) {
  if (text.trim().isEmpty) return null;
  final wert = betragAusEingabe(text);
  if (wert == null) return gebuehrensatzUnlesbarHinweis;
  if (wert < gebuehrensatzMinimum || wert > gebuehrensatzMaximum) {
    return gebuehrensatzBereichHinweis;
  }
  return null;
}

/// Dieselbe Prüfung für die beiden Korrekturfelder. Leer heißt hier „automatisch
/// nach § 13 RVG rechnen" und ist der Normalfall.
///
/// Unlesbares ist es nicht. Es fiel bis hierher stillschweigend auf
/// „automatisch" zurück — der Anwalt sah seinen eingetippten Betrag im Feld
/// stehen und bekam im Schreiben die errechnete Gebühr. Dieselbe stille Falle
/// wie beim Rückfall auf 1,3 im Gebührensatz, nur eine Zeile tiefer; beide
/// enden jetzt gleich: Feld markiert, Erzeugen gesperrt.
///
/// Der leere Fall wird **vor** dem Lesen abgefangen, nicht am `null` danach:
/// Beide ergeben `null`, bedeuten aber das Gegenteil voneinander.
String? korrekturbetragFehler(String text) {
  if (text.trim().isEmpty) return null;
  final wert = betragAusEingabe(text);
  if (wert == null) return unlesbarerBetragHinweis(text);
  if (wert < 0) return negativerKorrekturbetragHinweis;
  if (wert > korrekturbetragMaximum) return zuGrosserKorrekturbetragHinweis;
  return null;
}

/// Der Gebührensatz, der in die `DamageListing` geht. Der Rückfall auf 1,3 gilt
/// nur dort, wo er gemeint war — beim **leeren** Feld.
///
/// Steht etwas Unlesbares darin, geht 1,3 zwar weiter hinaus (die Aufstellung
/// braucht eine Zahl), aber [gebuehrensatzFehler] hat das Feld dann rot gemacht
/// und `schadensaufstellungIstErzeugbar` sperrt das Erzeugen. In ein Dokument
/// kommt der Rückfall so nicht mehr; sichtbar bleibt er nur in der Vorschau,
/// direkt neben dem markierten Feld.
double gebuehrensatzAusEingabe(String text) =>
    betragAusEingabe(text) ?? gebuehrensatzVorgabe;

/// Ein fertiger Satz je beanstandetem Feld, benannt wie das Feld im Formular —
/// dieselbe Bahn, die `schadenspositionenFehler` für die Zeilen benutzt.
List<String> rvgFelderFehler({
  required String gebuehrensatz,
  required String geschaeftsgebuehr,
  required String auslagenpauschale,
}) => [
  for (final (name, meldung) in [
    (gebuehrensatzFeldName, gebuehrensatzFehler(gebuehrensatz)),
    (geschaeftsgebuehrFeldName, korrekturbetragFehler(geschaeftsgebuehr)),
    (auslagenpauschaleFeldName, korrekturbetragFehler(auslagenpauschale)),
  ])
    if (meldung != null) '$name: $meldung',
];
