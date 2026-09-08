import 'package:automation_app/features/register_import/domain/entities/register_import_zeile.dart';
import 'package:automation_app/features/register_import/domain/entities/register_zeilen_befund.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_zeile_formular.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Was der Anwalt mit einer Registerzeile entschieden hat. `null` als Ergebnis
/// des Dialogs heißt „abgebrochen"; ein Ergebnis mit [geaendert] `null` heißt
/// „diese Zeile ganz weglassen".
class RegisterZeileEntscheidung {
  final RegisterImportZeile? geaendert;

  const RegisterZeileEntscheidung.uebernehmen(RegisterImportZeile zeile)
    : geaendert = zeile;

  const RegisterZeileEntscheidung.verwerfen() : geaendert = null;
}

/// Berichtigt eine Zeile der Registerdatei, bevor sie geschrieben wird (§6.2).
///
/// Ohne diesen Weg wäre ein Jahrgang alles oder nichts: eine einzige falsch
/// zerlegte Zelle zwänge dazu, entweder den Fehler mitzunehmen oder
/// zweihundert richtige Zeilen liegen zu lassen. Geändert wird nur die Fassung
/// im Arbeitsspeicher — die Datei auf der Platte bleibt, wie sie ist, und
/// „Andere Datei" holt jederzeit den Urzustand zurück.
class RegisterImportZeileDialog extends StatefulWidget {
  /// Was der Dienst zu dieser Zeile gesagt hat — der Grund, sie anzusehen.
  final RegisterZeilenBefund befund;

  /// Der Datensatz aus der Datei, der hier bearbeitet wird.
  final RegisterImportZeile datensatz;

  const RegisterImportZeileDialog({
    super.key,
    required this.befund,
    required this.datensatz,
  });

  @override
  State<RegisterImportZeileDialog> createState() =>
      _RegisterImportZeileDialogState();
}

class _RegisterImportZeileDialogState extends State<RegisterImportZeileDialog> {
  late final FormGroup _form = FormGroup({
    'abteilung': FormControl<String>(value: widget.datensatz.abteilung),
    'rechtsgebiet': FormControl<String>(value: widget.datensatz.rechtsgebiet),
    'sachart': FormControl<String>(value: widget.datensatz.sachart),
    'mandant': FormControl<String>(value: widget.datensatz.mandant),
    'gegner': FormControl<String>(value: widget.datensatz.gegner),
    'sachbestand': FormControl<String>(value: widget.datensatz.sachbestand),
    'unfalldatum': FormControl<String>(value: widget.datensatz.unfalldatum),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nummer = widget.befund.laufendeNummer;
    return ReactiveForm(
      formGroup: _form,
      child: AlertDialog(
        title: Text('Nr. $nummer / ${widget.befund.jahrgang} bearbeiten'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [_herkunft(theme), const RegisterImportZeileFormular()],
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
              const RegisterZeileEntscheidung.verwerfen(),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Zeile weglassen'),
          ),
          FilledButton(
            onPressed: _speichern,
            // Nicht bloss „Übernehmen": so heisst daneben der Knopf, der den
            // Jahrgang in die Datenbank schreibt. Hier wird nur die Zeile im
            // Arbeitsspeicher berichtigt.
            child: const Text('Änderung übernehmen'),
          ),
        ],
      ),
    );
  }

  /// Der Wortlaut aus dem Word-Register und das, was Erzeuger und Dienst daran
  /// auszusetzen hatten. Ohne den Beleg daneben wäre nicht zu entscheiden, was
  /// hier richtig ist — die Vorlage steht schließlich nicht auf dem Bildschirm.
  Widget _herkunft(ThemeData theme) {
    final zeile = widget.datensatz;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            'Im Register: ${zeile.freitext.isEmpty ? '—' : zeile.freitext}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Spalte 1: ${zeile.spalte1.isEmpty ? '—' : zeile.spalte1} · '
            'Abteilung wie geschrieben: '
            '${zeile.abteilungRoh.isEmpty ? '—' : zeile.abteilungRoh} · '
            '${widget.befund.sicherheit.bezeichnung}',
            style: theme.textTheme.bodySmall,
          ),
          for (final meldung in widget.befund.befunde)
            Text(
              meldung,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          for (final hinweis in widget.befund.hinweise)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
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
      RegisterZeileEntscheidung.uebernehmen(
        widget.datensatz.copyWith(
          abteilung: lies('abteilung'),
          rechtsgebiet: lies('rechtsgebiet'),
          sachart: lies('sachart'),
          mandant: lies('mandant'),
          gegner: lies('gegner'),
          sachbestand: lies('sachbestand'),
          unfalldatum: lies('unfalldatum'),
        ),
      ),
    );
  }
}
