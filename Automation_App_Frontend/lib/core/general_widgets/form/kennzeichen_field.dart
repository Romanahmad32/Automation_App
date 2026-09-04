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
/// [normalizeKennzeichen], aus `hge1427` wird also von allein `HG-E 1427`.
/// Beanstandet wird deshalb nur, was sich als Kennzeichen überhaupt nicht
/// lesen lässt ([istKennzeichen]). Die frühere strenge Prüfung in „Vorgang
/// starten" verlangte den Bindestrich vom Anwalt und beanstandete damit auch
/// Werte, die die App selbst aus dem Register angeboten hatte — eine
/// Sackgasse, in der das Formular auf eine Schreibweise wartete, die es
/// nebenher schon herstellen konnte.
class KennzeichenField extends StatelessWidget {
  /// Fehlerschlüssel des [validator]. Eigener Schlüssel statt
  /// `ValidationMessage.pattern`: An einem Feld können mehrere Formatprüfungen
  /// hängen, und ein geteilter Schlüssel liesse deren Meldungen einander
  /// überschreiben.
  static const formatError = 'kennzeichen';

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
      // Aus `HGE1427` wird `HG-E 1427`; was sich nicht lesen lässt, bleibt
      // stehen und wird vom [validator] beanstandet — Raten wäre hier
      // schlimmer als eine Meldung.
      normalisiere: (eingabe) => normalizeKennzeichen(eingabe) ?? eingabe,
    );
  }

  /// Validator für das Control hinter diesem Feld: leere Werte sind gültig
  /// (Pflicht regelt der Required-Validator daneben), sonst muss der Wert als
  /// Kennzeichen lesbar sein.
  static Map<String, dynamic>? validator(AbstractControl<dynamic> control) {
    final wert = (control.value as String?)?.trim() ?? '';
    if (wert.isEmpty || istKennzeichen(wert)) return null;
    return {formatError: true};
  }

  /// Die Meldungen dieses Felds, zum Hereingeben in ein anderes Eingabefeld,
  /// das auf demselben Control sitzt.
  static Map<String, String Function(Object)> get meldungen => {
    formatError: (Object _) => hinweis,
  };
}
