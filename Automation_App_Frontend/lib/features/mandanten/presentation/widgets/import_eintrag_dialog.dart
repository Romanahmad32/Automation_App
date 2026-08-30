import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_eintrag_formular.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Was der Anwalt mit einer Importzeile entschieden hat. `null` als Ergebnis
/// des Dialogs heißt „abgebrochen"; ein Ergebnis mit [geaendert] `null` heißt
/// „diese Zeile ganz weglassen".
class ImportEintragEntscheidung {
  final ImportMandantEintrag? geaendert;

  const ImportEintragEntscheidung.uebernehmen(ImportMandantEintrag eintrag)
    : geaendert = eintrag;

  const ImportEintragEntscheidung.verwerfen() : geaendert = null;
}

/// Berichtigt eine Zeile der Importdatei, bevor sie übernommen wird.
///
/// Ohne diesen Weg wäre eine Datei alles oder nichts: eine einzige falsch
/// gelesene Anschrift zwänge dazu, entweder den Fehler mitzunehmen oder
/// viertausend richtige Zeilen liegen zu lassen. Geändert wird nur die Fassung
/// im Arbeitsspeicher — die Datei auf der Platte bleibt, wie sie ist, und
/// „Andere Datei" holt jederzeit den Urzustand zurück.
class ImportEintragDialog extends StatefulWidget {
  /// Was der Dienst zu dieser Zeile gesagt hat — der Grund, sie anzusehen.
  final ImportEintrag befund;

  /// Der Datensatz aus der Datei, der hier bearbeitet wird.
  final ImportMandantEintrag datensatz;

  const ImportEintragDialog({
    super.key,
    required this.befund,
    required this.datensatz,
  });

  @override
  State<ImportEintragDialog> createState() => _ImportEintragDialogState();
}

class _ImportEintragDialogState extends State<ImportEintragDialog> {
  late Anrede _anrede = Anrede.fromValue(widget.datensatz.anrede);
  late List<String> _ordnernamen = List.of(widget.datensatz.aktenOrdnernamen);
  late List<String> _kennzeichen = List.of(widget.datensatz.kennzeichen);

  late final FormGroup _form = FormGroup({
    'vorname': FormControl<String>(value: widget.datensatz.vorname),
    'nachname': FormControl<String>(
      value: widget.datensatz.nachname,
      validators: [Validators.required],
    ),
    'strasseHausnummer': FormControl<String>(
      value: widget.datensatz.strasseHausnummer,
    ),
    'postleitzahl': FormControl<String>(value: widget.datensatz.postleitzahl),
    'ort': FormControl<String>(value: widget.datensatz.ort),
    'emailAdresse': FormControl<String>(
      value: widget.datensatz.emailAdresse,
      validators: [Validators.email],
    ),
    'telefonnummer': FormControl<String>(value: widget.datensatz.telefonnummer),
    'notiz': FormControl<String>(value: widget.datensatz.notiz),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Das Formular spannt sich ueber Inhalt und Schaltflaechen: „Übernehmen"
    // liegt in actions und muss trotzdem sehen, ob die Eingaben gueltig sind.
    return ReactiveForm(
      formGroup: _form,
      child: AlertDialog(
        title: Text('Zeile ${widget.befund.zeile + 1} bearbeiten'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _herkunft(theme),
                ImportEintragFormular(
                  initialAnrede: _anrede,
                  initialOrdnernamen: _ordnernamen,
                  initialKennzeichen: _kennzeichen,
                  onAnrede: (wert) => _anrede = wert,
                  onOrdnernamen: (werte) => _ordnernamen = werte,
                  onKennzeichen: (werte) => _kennzeichen = werte,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const ImportEintragEntscheidung.verwerfen(),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Zeile weglassen'),
          ),
          ReactiveFormConsumer(
            builder: (context, form, _) => FilledButton(
              onPressed: form.valid ? _speichern : null,
              // Nicht bloss „Übernehmen": so heisst in der Vorschau daneben
              // der Knopf, der ins Register schreibt. Hier wird nur die Zeile
              // im Arbeitsspeicher berichtigt.
              child: const Text('Änderung übernehmen'),
            ),
          ),
        ],
      ),
    );
  }

  /// Woher die Angaben stammen und was der Dienst daran auszusetzen hatte —
  /// beides steht hier, weil sonst nicht zu erkennen ist, was zu berichtigen
  /// wäre.
  Widget _herkunft(ThemeData theme) {
    final quelle = widget.datensatz.quelle;
    final hinweise = widget.befund.hinweise;
    if (quelle.isEmpty && hinweise.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quelle.isNotEmpty)
            Text(
              'Gefunden in: $quelle (${widget.befund.sicherheit.bezeichnung})',
              style: theme.textTheme.bodySmall,
            ),
          for (final hinweis in hinweise)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  void _speichern() {
    String lies(String feld) =>
        (_form.control(feld).value as String?)?.trim() ?? '';

    Navigator.pop(
      context,
      ImportEintragEntscheidung.uebernehmen(
        ImportMandantEintrag(
          anrede: _anrede.value,
          vorname: lies('vorname'),
          nachname: lies('nachname'),
          strasseHausnummer: lies('strasseHausnummer'),
          postleitzahl: lies('postleitzahl'),
          ort: lies('ort'),
          emailAdresse: lies('emailAdresse'),
          telefonnummer: lies('telefonnummer'),
          notiz: lies('notiz'),
          aktenOrdnernamen: _ordnernamen,
          kennzeichen: _kennzeichen,
          // Herkunft und Selbsteinschaetzung bleiben, wie der Erzeuger sie
          // gemeldet hat: sie beschreiben den Fund, nicht den Mandanten.
          quelle: widget.datensatz.quelle,
          sicherheit: widget.datensatz.sicherheit,
        ),
      ),
    );
  }
}
