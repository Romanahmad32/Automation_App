import 'package:flutter/material.dart';
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

  final String formControlName;
  final String? labelText;
  final String? helperText;

  /// Grenzen des Kalender-Dialogs; Standard: ±10 Jahre um heute.
  final DateTime? firstDate;
  final DateTime? lastDate;

  final Map<String, String Function(Object)>? validationMessages;

  const GermanDateField({
    super.key,
    required this.formControlName,
    this.labelText,
    this.helperText,
    this.firstDate,
    this.lastDate,
    this.validationMessages,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveTextField<String>(
      formControlName: formControlName,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      validationMessages: {
        formatError: (_) => 'Datum im Format TT.MM.JJJJ angeben',
        rangeError: (_) => 'Datum außerhalb des zulässigen Zeitraums',
        ...?validationMessages,
      },
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
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

    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 10);
    final last = lastDate ?? DateTime(now.year + 10);
    // initialDate muss innerhalb der Grenzen liegen, sonst wirft der Dialog.
    var initial = parseDate(control.value) ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      control.value = formatDate(picked);
    }
  }

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.'
          '${date.year.toString().padLeft(4, '0')}';

  /// Liest ein Datum im Format T(T).M(M).JJJJ; null bei leerem,
  /// formal ungültigem oder nicht existierendem Wert (z. B. 31.02.).
  static DateTime? parseDate(String? value) {
    final match = RegExp(
      r'^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*$',
    ).firstMatch(value ?? '');
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
      final value = (control.value as String?)?.trim() ?? '';
      if (value.isEmpty) {
        return null;
      }
      final date = parseDate(value);
      if (date == null) {
        return {formatError: true};
      }
      if (firstDate != null && date.isBefore(_dateOnly(firstDate))) {
        return {rangeError: true};
      }
      if (lastDate != null && date.isAfter(_dateOnly(lastDate))) {
        return {rangeError: true};
      }
      return null;
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
