import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Datumsfeld im Format TT.MM.JJJJ für Formulare **ohne** reactive_forms —
/// dieselbe Prüfung, dieselben Sätze und derselbe Kalender wie
/// [GermanDateField], aber auf einem [TextEditingController]. Wo ein
/// `FormGroup` das Formular trägt, bleibt [GermanDateField] der Baustein.
///
/// **Es sperrt nichts.** Ein Wert, der kein Datum ist, wird angemerkt — in
/// der Hinweisfarbe unter dem Feld, mit dem Satz aus
/// [GermanDateField.meldungen] — und bleibt stehen, wie er eingegeben wurde.
/// Ob ein Formular daran etwas aufhält, entscheidet der Aufrufer, nicht das
/// Feld.
///
/// Angemerkt wird, solange das Feld nicht den Fokus hat: Während des Tippens
/// ist `03.1` noch kein Fehler. Ein vorbelegter Wert, den niemand anfasst,
/// bekommt seinen Hinweis dagegen sofort — er hört auf den Wert, nicht auf
/// eine Berührung (wie `KennzeichenField`).
class GermanDateTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;

  /// Was ohne Beanstandung unter dem Feld steht. Eine Beanstandung des
  /// Formats verdrängt ihn, solange sie gilt.
  final String? helperText;
  final TextStyle? helperStyle;

  /// Über wie viele Zeilen [helperText] laufen darf. Ohne Angabe gilt die
  /// Vorgabe von Material (eine Zeile, danach „…").
  final int? helperMaxLines;

  /// Grenzen für Kalender und Prüfung; ohne Angabe prüft das Feld nur das
  /// Format, und der Kalender reicht ±10 Jahre um heute.
  final DateTime? firstDate;
  final DateTime? lastDate;

  final bool enabled;
  final bool isDense;

  /// Key des inneren [TextField] — für Tests und die Bedienung von außen
  /// (Marionette), die ein Eingabefeld erwarten, nicht diesen Rahmen.
  final Key? fieldKey;

  /// Bei jeder Eingabe — und nach einer Wahl im Kalender, die den Text
  /// setzt, ohne zu tippen.
  final ValueChanged<String>? onChanged;

  const GermanDateTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.helperText,
    this.helperStyle,
    this.helperMaxLines,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.isDense = false,
    this.fieldKey,
    this.onChanged,
  });

  /// Was zu [eingabe] anzumerken ist — `null` heißt: nichts, auch bei einem
  /// leeren Wert. Der Satz ist derselbe, den [GermanDateField] zeigt.
  static String? beanstandung(
    String eingabe, {
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final fehler = GermanDateField.pruefe(
      eingabe,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    return fehler == null ? null : GermanDateField.meldungen[fehler]!(true);
  }

  @override
  State<GermanDateTextField> createState() => GermanDateTextFieldState();
}

class GermanDateTextFieldState extends State<GermanDateTextField> {
  final FocusNode _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fokus.addListener(_fokusGewechselt);
  }

  @override
  void dispose() {
    _fokus
      ..removeListener(_fokusGewechselt)
      ..dispose();
    super.dispose();
  }

  void _fokusGewechselt() => setState(() {});

  Future<void> _waehle() async {
    final gewaehlt = await GermanDateField.waehleImKalender(
      context,
      wert: widget.controller.text,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (gewaehlt == null || !mounted) return;
    final text = GermanDateField.formatDate(gewaehlt);
    widget.controller.text = text;
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, wert, _) {
        final meldung = _fokus.hasFocus
            ? null
            : GermanDateTextField.beanstandung(
                wert.text,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
              );
        return TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          focusNode: _fokus,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            // Hinweis, nicht errorText: Ein errorText färbt das Feld rot und
            // liest sich wie eine Sperre — das Feld sperrt aber nichts.
            helperText: meldung ?? widget.helperText,
            helperStyle: meldung == null
                ? widget.helperStyle
                : TextStyle(color: Theme.of(context).colorScheme.tertiary),
            helperMaxLines: meldung == null ? widget.helperMaxLines : 3,
            hintText: 'TT.MM.JJJJ',
            border: const OutlineInputBorder(),
            isDense: widget.isDense,
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Datum im Kalender wählen',
              onPressed: widget.enabled ? _waehle : null,
            ),
          ),
        );
      },
    );
  }
}
