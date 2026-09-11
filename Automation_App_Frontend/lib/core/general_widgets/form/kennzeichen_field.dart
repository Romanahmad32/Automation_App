import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Eingabefeld für ein Kfz-Kennzeichen — **der** Baustein dafür, überall wo
/// eines erfasst wird: ein Hinweis, eine Auffassung.
///
/// Gebaut wie `GermanDateField`: Das Widget zeigt das Feld und darunter, was
/// aufgefallen ist. Darunter steckt ein [AuswahlTextField] — das Symbol rechts
/// öffnet die bekannten Werte, sobald [kandidaten] gefüllt ist.
///
/// **Dieses Feld sperrt nichts.** Welche Fahrzeuge in eine Kanzlei kommen,
/// entscheidet nicht die App: Ein E-Scooter trägt ein Versicherungskennzeichen
/// (`123 ABC` — drei Ziffern über drei Buchstaben), ein Behördenwagen `Y-123456`
/// oder `THW-12345`, der Unfallgegner womöglich ein französisches `AB-123-CD`.
/// Alles davon ist Alltag und keines passt ins Pkw-Schema. Früher hing hier ein
/// blockierender Validator; er hat ein E-Scooter-Mandat komplett aufgehalten
/// (#130) — weder „Vorgang speichern" noch „Dokument erstellen" waren
/// erreichbar.
///
/// **Und es schreibt nichts um** (§4.2, geändert am 11.09.2026). Bis dahin
/// stellte es beim Verlassen die Schreibweise mit Bindestrich her, sobald die
/// Lesart feststand (`hg-e1427` → `HG-E 1427`); jetzt steht im Feld — und
/// damit in Referenz, Vorgang und Schreiben —, was eingegeben wurde. Wo die
/// App zwei Werte vergleicht, sieht sie von der Schreibweise ab
/// ([gleichesKennzeichen]).
///
/// **Was auffällt, wird gesagt — unaufgefordert.** Unter dem Feld steht,
/// wenn der Wert kein Pkw-Kennzeichen ist ([unbekanntHinweis]) oder wenn er
/// mehrdeutig ist (`HGE1427` → `HG-E 1427` oder `H-GE 1427`?). Als **Hinweis**
/// in der Aufmerksamkeitsfarbe, nicht als Fehler: Der Anwalt sieht, dass ein
/// Bindestrich die Sache klären würde, und entscheidet selbst.
/// Unaufgefordert heißt nicht ungeduldig: Was noch ein Kennzeichen werden
/// kann (`HG-E 1`), bleibt unkommentiert, bis feststeht, dass es keines wird
/// ([beanstandung]).
class KennzeichenField extends StatelessWidget {
  /// Der neutrale Hilfetext eines leeren Felds: Er **nennt die Konvention mit
  /// Beispiel**, statt „ungültig" zu sagen — `HG-E 1427` erklärt in vier
  /// Zeichen, was drei Sätze bräuchten.
  static const hinweis = 'Kennzeichen wie HG-E 1427 eingeben';

  /// Der Hinweis zu einem Wert, den die App nicht als Kfz-Kennzeichen liest.
  /// Sagt ausdrücklich, was **stattdessen** geschieht — sonst liest sich jeder
  /// Hinweis unter einem Feld wie eine Ablehnung.
  static const unbekanntHinweis =
      'Nicht als Kfz-Kennzeichen erkannt — wird übernommen, wie eingegeben';

  final String formControlName;
  final String labelText;
  final String? helperText;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…") — in schmalen Spalten ist
  /// das zu wenig, dort gehören 2 hin.
  final int? helperMaxLines;

  /// Meldungen der Validatoren am selben Control (z. B. `required`) — dieses
  /// Feld bringt keine eigenen mehr mit.
  final Map<String, String Function(Object)>? validationMessages;

  /// Die Kennzeichen, die zur Wahl stehen. **Leer heißt: kein Symbol** — die
  /// freie Eingabe bleibt immer möglich.
  final List<AuswahlKandidat> kandidaten;

  final String dialogTitel;

  const KennzeichenField({
    super.key,
    required this.formControlName,
    this.labelText = 'Kennzeichen',
    this.helperText,
    this.helperMaxLines,
    this.validationMessages,
    this.kandidaten = const [],
    this.dialogTitel = 'Kennzeichen wählen',
  });

  @override
  Widget build(BuildContext context) {
    // Auf den Wert hören, nicht auf `touched`: Ein **vorbelegtes** Kennzeichen
    // wird nie angefasst, und ein Hinweis, den man erst durch Anfassen zu
    // sehen bekommt, ist bei genau dem Wert still, der ihn am nötigsten hat
    // (#130).
    return ReactiveValueListenableBuilder<String>(
      formControlName: formControlName,
      builder: (context, control, child) {
        final notiz = beanstandung(control.value ?? '');
        return AuswahlTextField(
          formControlName: formControlName,
          labelText: labelText,
          helperText: hilfetext(helperText, notiz),
          // Der Hinweis nennt bei Mehrdeutigkeit beide Lesarten und tritt zu
          // dem, was der Aufrufer schon sagt — beides zusammen braucht mehr
          // als die eine Zeile, die Material vorgibt.
          helperMaxLines: notiz == null
              ? helperMaxLines
              : (helperMaxLines ?? 1) + 2,
          helperStyle: notiz == null
              ? null
              : TextStyle(color: Theme.of(context).colorScheme.tertiary),
          validationMessages: validationMessages,
          kandidaten: kandidaten,
          dialogTitel: dialogTitel,
        );
      },
    );
  }

  /// Was zu [eingabe] anzumerken ist — `null` heißt: nichts. Der Text ist ein
  /// **Hinweis**, keine Ablehnung: Er entscheidet nirgends, ob ein Wert
  /// übernommen wird, sondern nur, was unter dem Feld steht.
  ///
  /// Drei Fälle, und die beiden beanstandeten bleiben unterscheidbar:
  /// eindeutig lesbar → nichts; mehrfach lesbar → [mehrdeutigHinweis] mit den
  /// Lesarten; sonst → [unbekanntHinweis].
  ///
  /// **Ein halb getipptes Kennzeichen ist noch keines** und wird deshalb nicht
  /// angemerkt ([beginntWieKennzeichen]): Sonst stünde „nicht erkannt" unter
  /// dem Feld, während `HG-E 1427` entsteht — bei acht von neun Zeichen —, und
  /// verschwände erst beim letzten. Ein Wert, aus dem nie ein Kennzeichen
  /// werden kann (`123 ABC`, `mein Auto`), bekommt seinen Hinweis dagegen
  /// sofort und ohne Anfassen.
  static String? beanstandung(String eingabe) {
    final lesarten = kennzeichenLesarten(eingabe);
    if (lesarten.length == 1) return null;
    if (lesarten.length > 1) return mehrdeutigHinweis(lesarten);
    if (eingabe.trim().isEmpty) return null;
    return beginntWieKennzeichen(eingabe) ? null : unbekanntHinweis;
  }

  /// Die Hilfszeile unter dem Feld: die des Aufrufers **und** die Anmerkung,
  /// nicht die eine statt der anderen.
  ///
  /// Der Aufrufer sagt dort Dinge, die nicht wegfallen dürfen, weil ein Wert
  /// ungewöhnlich ist: „* Pflichtfeld" und die Herkunft der Vorbelegung
  /// (`FormTemplateBuilder`). Genau am E-Scooter-Kennzeichen, für das dieses
  /// Feld gebaut ist, verschwänden sie sonst beide.
  static String? hilfetext(String? basis, String? notiz) {
    if (notiz == null) return basis;
    return basis == null || basis.isEmpty ? notiz : '$basis · $notiz';
  }

  /// Die Meldung zu einem mehrdeutigen Wert. Die [lesarten] **werden
  /// genannt**, denn ein Hinweis, der nur „mehrdeutig" sagt, lässt den Anwalt
  /// raten, was die App meint.
  static String mehrdeutigHinweis(List<String> lesarten) {
    if (lesarten.isEmpty) return hinweis;
    return 'Mehrdeutig, bitte mit Bindestrich: ${_aufzaehlung(lesarten)}';
  }

  /// „a, b oder c" — die letzte Lesart mit „oder" angehängt, die davor mit
  /// Komma.
  static String _aufzaehlung(List<String> werte) {
    if (werte.length == 1) return werte.single;
    final vordere = werte.sublist(0, werte.length - 1).join(', ');
    return '$vordere oder ${werte.last}';
  }
}
