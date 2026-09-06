import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_aehnlichkeits_hinweis.dart';
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

  /// Registereinträge mit ähnlichem Namen — der Hinweis, dass diese Zeile
  /// womöglich eine Dublette anlegt. Nur Zeilen mit [ImportArt.neu] haben
  /// welche; für alle anderen hat der Dienst den Mandanten längst gefunden.
  final List<MandantVorschlag> vorschlaege;

  /// Der gescannte Ordnerbestand, aus dem die Akten-Ordner gewählt werden.
  final List<String> vorhandeneOrdner;

  const ImportEintragDialog({
    super.key,
    required this.befund,
    required this.datensatz,
    this.vorschlaege = const [],
    this.vorhandeneOrdner = const [],
  });

  @override
  State<ImportEintragDialog> createState() => _ImportEintragDialogState();
}

class _ImportEintragDialogState extends State<ImportEintragDialog> {
  late Anrede _anrede = Anrede.fromValue(widget.datensatz.anrede);
  late List<String> _ordnernamen = List.of(widget.datensatz.aktenOrdnernamen);
  late List<String> _kennzeichen = List.of(widget.datensatz.kennzeichen);

  /// Ob der Anwalt einen der Vorschläge schon übernommen hat. Danach steht der
  /// Name im Formular, und der Hinweis daneben hätte nichts mehr zu sagen.
  bool _vorschlagUebernommen = false;

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
                if (widget.vorschlaege.isNotEmpty && !_vorschlagUebernommen)
                  ImportAehnlichkeitsHinweis(
                    vorschlaege: widget.vorschlaege,
                    onUebernehmen: _vorschlagUebernehmen,
                  ),
                ImportEintragFormular(
                  initialAnrede: _anrede,
                  initialOrdnernamen: _ordnernamen,
                  initialKennzeichen: _kennzeichen,
                  vorhandeneOrdner: widget.vorhandeneOrdner,
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

  /// Übernimmt den Namen des vorgeschlagenen Mandanten in die Zeile.
  ///
  /// Übernommen wird **nur der Name**, keine Kennung. Die Importdatei kennt
  /// keine Schlüssel — die vergibt die Datenbank —, und der Dienst findet den
  /// Mandanten über denselben Namensvergleich wieder, mit dem das Register
  /// seine Dubletten erkennt. Aus der Zeile wird damit regelkonform
  /// „ergänzt", ohne dass die Oberfläche eine zweite Zuordnungslogik
  /// mitbrächte.
  ///
  /// Die Anschrift bleibt stehen, wie sie in der Datei steht: „Ergänzen, nie
  /// überschreiben" entscheidet darüber im Dienst, nicht dieser Klick. Und
  /// `quelle`/`sicherheit` fasst er ohnehin nicht an — sie beschreiben den
  /// Fund, nicht den Mandanten.
  void _vorschlagUebernehmen(Mandant mandant) {
    setState(() {
      _form.control('vorname').value = mandant.vorname;
      _form.control('nachname').value = mandant.nachname;
      _vorschlagUebernommen = true;
    });
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
