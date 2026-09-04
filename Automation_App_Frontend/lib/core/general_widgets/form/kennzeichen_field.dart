import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:automation_app/core/general_widgets/form/auswahl_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Eingabefeld für ein Kfz-Kennzeichen — **der** Baustein dafür, überall wo
/// eines erfasst wird: eine Prüfung, eine Meldung, eine Normalisierung.
///
/// Gebaut wie `GermanDateField`: Das Widget zeigt das Feld und die Meldungen,
/// die Prüfung selbst ist [validator] und wird beim Aufbau der FormGroup am
/// Control registriert. Darunter steckt ein [AuswahlTextField] — das Symbol
/// rechts öffnet die bekannten Werte, sobald [kandidaten] gefüllt ist.
///
/// **Tolerant prüfen und normalisieren, statt den Bindestrich zu verlangen.**
/// Der Baustein stellt die Konvention `HG-E 1427` selbst her: beim Verlassen
/// des Felds und für jede Eingabe im Auswahldialog läuft der Wert durch
/// [normalizeKennzeichen], aus `hg-e1427` wird also von allein `HG-E 1427`.
/// Beanstandet wird deshalb nur, was sich als Kennzeichen überhaupt nicht
/// lesen lässt. Die frühere strenge Prüfung in „Vorgang starten" verlangte den
/// Bindestrich vom Anwalt und beanstandete damit auch Werte, die die App selbst
/// aus dem Register angeboten hatte — eine Sackgasse, in der das Formular auf
/// eine Schreibweise wartete, die es nebenher schon herstellen konnte.
///
/// **Toleranz hört bei der Mehrdeutigkeit auf.** `HGE1427` kann `HG-E 1427`
/// oder `H-GE 1427` heißen, und das sind zwei verschiedene Fahrzeuge. Solche
/// Eingaben werden nicht geraten, sondern mit ihren Lesarten zurückgemeldet
/// ([mehrdeutigError]) — der Anwalt setzt den Bindestrich, und die App
/// schreibt kein fremdes Kennzeichen ins Anspruchsschreiben.
class KennzeichenField extends StatelessWidget {
  /// Fehlerschlüssel des [validator]. Eigener Schlüssel statt
  /// `ValidationMessage.pattern`: An einem Feld können mehrere Formatprüfungen
  /// hängen, und ein geteilter Schlüssel liesse deren Meldungen einander
  /// überschreiben.
  static const formatError = 'kennzeichen';

  /// Fehlerschlüssel für eine Eingabe, die sich lesen lässt — **aber auf
  /// mehrere Arten**. Eigener Schlüssel neben [formatError], weil es eine
  /// andere Auskunft ist: nicht „das ist kein Kennzeichen", sondern „welches
  /// davon meinen Sie?". Der **Fehlerwert ist die Liste der Lesarten**, damit
  /// [meldungen] sie nennen kann — reactive_forms reicht den Wert an die
  /// Meldungsfunktion durch (`String Function(Object error)`).
  static const mehrdeutigError = 'kennzeichenMehrdeutig';

  /// Die Meldung dazu — sie **nennt die Konvention mit Beispiel**, statt
  /// „ungültig" zu sagen: `HG-E 1427` erklärt in vier Zeichen, was drei Sätze
  /// bräuchten. Auch für Eingaben außerhalb von reactive_forms (Chip-Editoren,
  /// Dialoge) der eine Hinweistext.
  static const hinweis = 'Kennzeichen wie HG-E 1427 eingeben';

  final String formControlName;
  final String labelText;
  final String? helperText;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…") — in schmalen Spalten ist
  /// das zu wenig, dort gehören 2 hin.
  final int? helperMaxLines;

  /// Meldungen weiterer Validatoren am selben Control (z. B. `required`). Sie
  /// werden über die Standardmeldungen gemischt.
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
    return AuswahlTextField(
      formControlName: formControlName,
      labelText: labelText,
      helperText: helperText,
      helperMaxLines: helperMaxLines,
      validationMessages: {...meldungen, ...?validationMessages},
      kandidaten: kandidaten,
      dialogTitel: dialogTitel,
      // Aus `hg-e1427` wird `HG-E 1427`; was mehrdeutig oder unlesbar ist,
      // bleibt stehen und wird vom [validator] beanstandet — Raten wäre hier
      // schlimmer als eine Meldung.
      normalisiere: (eingabe) => normalizeKennzeichen(eingabe) ?? eingabe,
    );
  }

  /// Validator für das Control hinter diesem Feld: leere Werte sind gültig
  /// (Pflicht regelt der Required-Validator daneben), eine eindeutige Lesart
  /// ist gültig; mehrere Lesarten melden [mehrdeutigError] **mit den
  /// Lesarten als Fehlerwert**, gar keine [formatError].
  static Map<String, dynamic>? validator(AbstractControl<dynamic> control) {
    final wert = (control.value as String?)?.trim() ?? '';
    if (wert.isEmpty) return null;

    final lesarten = kennzeichenLesarten(wert);
    if (lesarten.length == 1) return null;
    if (lesarten.length > 1) return {mehrdeutigError: lesarten};
    return {formatError: true};
  }

  /// Die Meldungen dieses Felds, zum Hereingeben in ein anderes Eingabefeld,
  /// das auf demselben Control sitzt.
  static Map<String, String Function(Object)> get meldungen => {
    formatError: (Object _) => hinweis,
    mehrdeutigError: mehrdeutigHinweis,
  };

  /// Die Meldung zu [mehrdeutigError]. [fehler] ist die Liste der Lesarten,
  /// wie [validator] sie ablegt — sie **wird genannt**, denn eine Meldung, die
  /// nur „mehrdeutig" sagt, lässt den Anwalt raten, was die App meint.
  static String mehrdeutigHinweis(Object fehler) {
    final lesarten = fehler is List
        ? [for (final lesart in fehler) '$lesart']
        : const <String>[];
    if (lesarten.isEmpty) return hinweis;
    return 'Mehrdeutig, bitte mit Bindestrich: ${_aufzaehlung(lesarten)}';
  }

  /// Die Beanstandung zu einer Eingabe **außerhalb** von reactive_forms
  /// (Chip-Editor, Bearbeiten-Dialog): `null` heißt in Ordnung, sonst ist das
  /// Ergebnis der Text fürs Feld. Damit dort dieselbe Auskunft steht wie im
  /// Formular — mehrdeutig sagt „mehrdeutig", nicht „kein Kennzeichen".
  static String? beanstandung(String eingabe) {
    final lesarten = kennzeichenLesarten(eingabe);
    if (lesarten.length == 1) return null;
    if (lesarten.length > 1) return mehrdeutigHinweis(lesarten);
    return hinweis;
  }

  /// „a, b oder c" — die letzte Lesart mit „oder" angehängt, die davor mit
  /// Komma.
  static String _aufzaehlung(List<String> werte) {
    if (werte.length == 1) return werte.single;
    final vordere = werte.sublist(0, werte.length - 1).join(', ');
    return '$vordere oder ${werte.last}';
  }
}
