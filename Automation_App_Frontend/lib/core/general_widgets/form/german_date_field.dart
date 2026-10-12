import 'package:automation_app/core/general_widgets/form/reactive_text_eingabe.dart';
import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Texteingabefeld für Datumsangaben im Format TT.MM.JJJJ.
///
/// Primär wird das Datum getippt; das Kalender-Icon rechts öffnet
/// zusätzlich den Auswahl-Dialog. Arbeitet auf einem `FormControl<String>`.
/// Die Format-/Bereichsprüfung übernimmt [validator] — den beim Aufbau
/// der FormGroup am Control registrieren (mit denselben Grenzen wie
/// [firstDate]/[lastDate], damit Dialog und Validierung übereinstimmen).
class GermanDateField extends StatelessWidget {
  /// Fehlerschlüssel des [validator] bei ungültigem Format oder
  /// nicht existierendem Datum (z. B. 31.02.).
  static const formatError = 'dateFormat';

  /// Fehlerschlüssel des [validator] bei Datum außerhalb der Grenzen.
  static const rangeError = 'dateRange';

  /// Die Meldungen dieses Felds — hier und nicht im `build`, damit auch die
  /// Sammelzeile über einem gesperrten Knopf (`FormularFehlerHinweis`) den
  /// **gleichen** Satz nennen kann wie das Feld selbst.
  ///
  /// Ein Feld und keine Getter-Eigenschaft: Der Getter baute die Karte bei
  /// jedem Zugriff neu, und die Sammelzeile fragt sie je ungültigem Control
  /// und je Neuaufbau — bei einem Formular, das auf jeden Tastendruck neu
  /// aufbaut. Unveränderlich, weil sie nun geteilt wird.
  static final Map<String, String Function(Object)> meldungen =
      Map.unmodifiable({
        formatError: (_) => 'Datum im Format TT.MM.JJJJ angeben',
        rangeError: (_) => 'Datum außerhalb des zulässigen Zeitraums',
      });

  final String formControlName;
  final String? labelText;
  final String? helperText;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…") — in schmalen Spalten ist
  /// das zu wenig, dort gehören 2 hin.
  final int? helperMaxLines;

  /// Grenzen des Kalender-Dialogs; Standard: ±10 Jahre um heute.
  final DateTime? firstDate;
  final DateTime? lastDate;

  final Map<String, String Function(Object)>? validationMessages;

  const GermanDateField({
    super.key,
    required this.formControlName,
    this.labelText,
    this.helperText,
    this.helperMaxLines,
    this.firstDate,
    this.lastDate,
    this.validationMessages,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveTextEingabe<String>(
      formControlName: formControlName,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      validationMessages: {...meldungen, ...?validationMessages},
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
        hintText: 'TT.MM.JJJJ',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Datum im Kalender wählen',
          onPressed: () => _pickDate(context),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final form = ReactiveForm.of(context, listen: false) as FormGroup;
    final control = form.control(formControlName) as FormControl<String>;

    final picked = await waehleImKalender(
      context,
      wert: control.value,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      control.value = formatDate(picked);
    }
  }

  /// Öffnet den Kalender und liefert den gewählten Tag; null, wenn der
  /// Anwalt abbricht. Aufgeschlagen wird bei [wert], sofern das ein Datum
  /// ist, sonst bei heute. Grenzen: [firstDate]/[lastDate], Standard ±10
  /// Jahre um heute.
  ///
  /// Geteilt mit `GermanDateTextField` — derselbe Kalender, ob das Feld an
  /// einem `FormControl` hängt oder an einem `TextEditingController`.
  static Future<DateTime?> waehleImKalender(
    BuildContext context, {
    String? wert,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 10);
    final last = lastDate ?? DateTime(now.year + 10);
    // initialDate muss innerhalb der Grenzen liegen, sonst wirft der Dialog.
    var initial = parseDate(wert) ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
  }

  static String formatDate(DateTime date) => deutschesDatum(date);

  /// Liest ein Datum im Format T(T).M(M).JJJJ; null bei leerem,
  /// formal ungültigem oder nicht existierendem Wert (z. B. 31.02.).
  static DateTime? parseDate(String? value) {
    final match = RegExp(r'^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*$')
        .firstMatch(value ?? '');
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    // DateTime normalisiert Überläufe (31.02. → 03.03.) statt zu werfen.
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  }

  /// Validator für das Control hinter diesem Feld: leere Werte sind gültig
  /// (Pflicht regelt der Required-Validator), sonst wird Format und —
  /// falls Grenzen angegeben — der Datumsbereich geprüft (nur Kalendertag,
  /// Uhrzeitanteile der Grenzen werden ignoriert).
  static Validator<dynamic> validator({
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return Validators.delegate((control) {
      final fehler = pruefe(
        control.value as String?,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      return fehler == null ? null : {fehler: true};
    });
  }

  /// Die Prüfung hinter [validator], ohne Control: [formatError],
  /// [rangeError] oder null. Leer ist gültig. Geteilt mit
  /// `GermanDateTextField`, damit beide Felder dasselbe beanstanden.
  static String? pruefe(
    String? value, {
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final date = parseDate(text);
    if (date == null) {
      return formatError;
    }
    if (firstDate != null && date.isBefore(_dateOnly(firstDate))) {
      return rangeError;
    }
    if (lastDate != null && date.isAfter(_dateOnly(lastDate))) {
      return rangeError;
    }
    return null;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
