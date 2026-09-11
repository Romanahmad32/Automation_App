import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sagt über einem gesperrten Knopf, **welches Feld** ihn sperrt und **warum** —
/// jeder Name anklickbar und springt (per Fokus) in sein Feld.
///
/// Vorgänger war `PflichtfelderHinweis`, der nur `required` kannte (#35 Teil 3).
/// Das reichte nicht: Ein halb getipptes oder ungültig vorbelegtes Datum sperrte
/// „Dokument erstellen" wortlos, weil reactive_forms den Fehler am Feld erst
/// zeigt, wenn es angefasst wurde (`reactive_form_field.dart`:
/// `control.invalid && touched`) — und ein gesperrter Knopf nimmt keinen Fokus,
/// also verlässt man das Feld nie. Weißes Feld, grauer Knopf, kein Wort dazu
/// (#130). Diese Zeile hört auf den **Wert**, nicht auf `touched`.
///
/// Zwei Abschnitte, weil es zwei verschiedene Auskünfte sind: was **fehlt**
/// (leere Pflichtfelder — der Wortlaut von #35 bleibt) und was **zu berichtigen**
/// ist (alles andere, mit dem Grund dahinter).
class FormularFehlerHinweis extends StatelessWidget {
  /// Die Felder, die hier gemeldet werden dürfen. `null` heißt: alle Controls
  /// der Gruppe. Eingeschränkt wird dort, wo ein Formular Controls führt, die
  /// gerade gar nicht sichtbar sind (`FormTemplateBuilder`, #82).
  final List<String>? felder;

  /// Anzeigenamen der Controls. Fehlt einer, steht der Control-Name da — bei
  /// Vorlagenfeldern ist der Name schon die Beschriftung, in handgebauten
  /// Formularen ist er technisch (`kennzeichenGegner`).
  final Map<String, String> beschriftungen;

  /// Zusätzliche Grundtexte **je Feld**, über [standardGruende] gemischt. Nötig,
  /// weil sich zwei Felder denselben Fehlerschlüssel teilen können und trotzdem
  /// Verschiedenes sagen (`ValidationMessage.pattern` heißt bei der Uhrzeit
  /// „HH:MM", bei der Vorgangsnummer „VU/1234567/2026").
  final Map<String, Map<String, String Function(Object)>> feldMeldungen;

  const FormularFehlerHinweis({
    super.key,
    this.felder,
    this.beschriftungen = const {},
    this.feldMeldungen = const {},
  });

  /// Die Grundtexte, die jedes Formular teilt. Die Datumstexte kommen von
  /// [GermanDateField], damit hier keine zweite Fassung derselben Meldung
  /// entsteht.
  ///
  /// Ein Feld und keine Getter-Eigenschaft: Diese Karte ist konstante Auskunft
  /// und wird je ungültigem Control gefragt — in einem `ReactiveFormConsumer`,
  /// der bei jedem Tastendruck neu aufbaut. Als Getter entstünde sie dabei
  /// jedes Mal neu, samt der Karte aus [GermanDateField] darin.
  static final Map<String, String Function(Object)> standardGruende =
      Map.unmodifiable({
        ...GermanDateField.meldungen,
        ValidationMessage.email: (_) => 'keine gültige E-Mail-Adresse',
        ValidationMessage.number: (_) => 'nur Ziffern',
        ValidationMessage.pattern: (_) =>
            'Format prüfen, siehe Hinweis am Feld',
        ValidationMessage.minLength: (_) => 'zu kurz',
        ValidationMessage.maxLength: (_) => 'zu lang',
      });

  @override
  Widget build(BuildContext context) {
    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        final namen = felder ?? formGroup.controls.keys.toList();
        final fehlend = <String>[];
        final beanstandet = <String, String>{};
        for (final name in namen) {
          final control = formGroup.controls[name];
          if (control == null || control.valid || control.disabled) continue;
          if (control.hasError(ValidationMessage.required)) {
            fehlend.add(name);
          } else {
            beanstandet[name] = _grund(name, control.errors);
          }
        }
        if (fehlend.isEmpty && beanstandet.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            if (fehlend.isNotEmpty)
              FehlerHinweis(
                nachricht: fehlend.length == 1
                    ? '1 Pflichtfeld fehlt:'
                    : '${fehlend.length} Pflichtfelder fehlen:',
                inhalt: _sprungziele(context, formGroup, {
                  for (final name in fehlend) name: _name(name),
                }),
              ),
            if (beanstandet.isNotEmpty)
              FehlerHinweis(
                nachricht: beanstandet.length == 1
                    ? '1 Feld ist noch zu berichtigen:'
                    : '${beanstandet.length} Felder sind noch zu berichtigen:',
                inhalt: _sprungziele(context, formGroup, {
                  for (final eintrag in beanstandet.entries)
                    eintrag.key: '${_name(eintrag.key)}: ${eintrag.value}',
                }),
              ),
          ],
        );
      },
    );
  }

  /// Der Grund zum ersten Fehler des Controls. Der erste genügt: Wer ihn
  /// behebt, sieht den nächsten — eine Aufzählung aller Beanstandungen eines
  /// Feldes in einer Sammelzeile wäre länger als das Formular selbst.
  ///
  /// **Ohne Fehlerschlüssel ist der Grund unbekannt, kein Absturz.** Ein
  /// Control in `ControlStatus.pending` kommt durch die Prüfung oben (`valid`
  /// ist `status == valid`, `pending` also nicht valide) und trägt zugleich
  /// eine leere Fehlerkarte. `keys.first` hätte hier geworfen — mitten im
  /// `build` eines Bausteins, den `core` überall einsetzt, und damit die ganze
  /// Seite mitgenommen statt einer Zeile.
  ///
  /// Die eigene Meldung des Felds geht vor, ohne dass dafür zwei Karten
  /// verschmolzen werden: Das geschähe je Control und je Neuaufbau.
  String _grund(String name, Map<String, dynamic> fehler) {
    if (fehler.isEmpty) return 'bitte prüfen';
    final schluessel = fehler.keys.first;
    final text =
        feldMeldungen[name]?[schluessel] ?? standardGruende[schluessel];
    return text?.call(fehler[schluessel] as Object) ?? 'bitte prüfen';
  }

  String _name(String control) => beschriftungen[control] ?? control;

  /// Die anklickbaren Einträge — je Control ein Text, der in sein Feld springt.
  Widget _sprungziele(
    BuildContext context,
    FormGroup formGroup,
    Map<String, String> eintraege,
  ) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final eintrag in eintraege.entries)
          InkWell(
            onTap: () => formGroup.control(eintrag.key).focus(),
            child: Text(
              eintrag.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
