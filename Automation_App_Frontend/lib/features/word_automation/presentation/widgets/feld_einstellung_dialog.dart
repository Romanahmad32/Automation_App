import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:flutter/material.dart';

/// Die Feldeinstellung eines Vorlagenfelds — Name, Typ, Pflichtangabe,
/// Datenquelle — als Dialog **über** dem Ausfüllformular.
///
/// Warum hier und nicht nur unter „Vorlagen Verwalten": Genau dieser Griff
/// trieb den Anwalt mitten im Ausfüllen auf eine andere Seite. Ein Haken, der
/// noch fallen muss, ein Feldname, der nicht passt — und beim Zurückkommen war
/// alles Eingetippte weg (#37). Der Dialog nimmt dem Problem den Auslöser,
/// statt nur seine Folgen zu mildern: Die Vorlage wird sofort gespeichert, das
/// Formular bleibt stehen.
///
/// Der Dialog **entscheidet nicht**, er liefert nur ab: Wer ihn öffnet, bekommt
/// das geänderte Feld zurück (oder `null` beim Abbrechen) und speichert selbst
/// — so bleibt die Zuständigkeit für die Vorlage beim [WizardCubit], der sie
/// ohnehin hält.
class FeldEinstellungDialog extends StatefulWidget {
  final FieldData feld;

  /// Die Namen der **übrigen** Felder derselben Vorlage. Zwei gleiche Namen
  /// wären dasselbe Feld: Die `FormGroup` des Formulars schlüsselt nach Namen,
  /// der zweite Eintrag verdrängte den ersten stillschweigend — und der Anwalt
  /// hätte ein Feld weniger, ohne dass ihm jemand etwas sagt.
  final List<String> belegteNamen;

  const FeldEinstellungDialog({
    super.key,
    required this.feld,
    required this.belegteNamen,
  });

  /// Öffnet den Dialog und liefert das geänderte Feld — `null`, wenn
  /// abgebrochen wurde.
  static Future<FieldData?> zeige(
    BuildContext context, {
    required FieldData feld,
    required List<String> belegteNamen,
  }) => showDialog<FieldData>(
    context: context,
    builder: (_) =>
        FeldEinstellungDialog(feld: feld, belegteNamen: belegteNamen),
  );

  /// Was am Feldnamen [name] auszusetzen ist — `null`, wenn nichts.
  ///
  /// Die Zeichenregel ist die des Dienstes (`^[\p{L}\p{N} _-]+$`). Der lehnt
  /// erst beim Erzeugen ab, mit einem HTTP 400: Ein Punkt oder Doppelpunkt im
  /// Feldnamen fiele sonst einen Arbeitsschritt zu spät auf — und der Anwalt
  /// stünde wieder vor einer Vorlage, die er bearbeiten muss.
  static String? beanstandung(String name, List<String> belegteNamen) {
    final getrimmt = name.trim();
    if (getrimmt.isEmpty) {
      return 'Der Feldname darf nicht leer sein.';
    }
    if (!_erlaubteZeichen.hasMatch(getrimmt)) {
      return 'Erlaubt sind Buchstaben, Ziffern, Leerzeichen, „-" und „_".';
    }
    final schonBelegt = belegteNamen.any(
      (belegt) => belegt.toLowerCase() == getrimmt.toLowerCase(),
    );
    if (schonBelegt) {
      return 'Ein Feld mit diesem Namen gibt es in der Vorlage schon.';
    }
    return null;
  }

  /// Dieselbe Regel wie `WordAutomationService` im Dienst. Groß-/Kleinschreibung
  /// spielt keine Rolle, der Platzhalter wird ohnehin ohne sie ersetzt.
  static final RegExp _erlaubteZeichen = RegExp(
    r'^[\p{L}\p{N} _-]+$',
    unicode: true,
  );

  @override
  State<FeldEinstellungDialog> createState() => _FeldEinstellungDialogState();
}

class _FeldEinstellungDialogState extends State<FeldEinstellungDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.feld.label,
  );
  late InputType _typ = widget.feld.inputType;
  late FeldDatenquelle _datenquelle = widget.feld.datenquelle;
  late bool _erforderlich = widget.feld.required;

  /// Erst beim Speicherversuch gesetzt — den Namen schon beim Tippen rot zu
  /// färben, hieße jedes halb getippte Wort zu beanstanden.
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _speichern() {
    final beanstandung = FeldEinstellungDialog.beanstandung(
      _name.text,
      widget.belegteNamen,
    );
    if (beanstandung != null) {
      setState(() => _fehler = beanstandung);
      return;
    }
    Navigator.of(context).pop(
      widget.feld.copyWith(
        label: _name.text.trim(),
        inputType: _typ,
        required: _erforderlich,
        datenquelle: _datenquelle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Vier Einstellungen samt Hinweiszeilen sind höher als ein niedriges
      // Fenster: ohne das scrollt der Dialog nicht, sondern schneidet ab.
      scrollable: true,
      title: const Text('Feldeinstellung'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Feldname',
                helperText:
                    'Zugleich der Platzhalter in der Word-Datei: {{Feldname}}',
                helperMaxLines: 2,
                errorText: _fehler,
                border: const OutlineInputBorder(),
              ),
              // Der Fehler gehört zum abgelehnten Stand, nicht zum Feld: Sobald
              // der Anwalt etwas ändert, ist er beantwortet.
              onChanged: (_) {
                if (_fehler != null) setState(() => _fehler = null);
              },
              onSubmitted: (_) => _speichern(),
            ),
            SearchableDropdown<InputType>(
              value: _typ,
              labelText: 'Feldtyp',
              hintText: 'Typ suchen oder auswählen',
              entries: [
                for (final typ in InputType.values)
                  SearchableDropdownEntry(value: typ, label: typ.displayName),
              ],
              onChanged: (wert) => setState(() => _typ = wert ?? _typ),
            ),
            SearchableDropdown<FeldDatenquelle>(
              value: _datenquelle,
              labelText: 'Datenquelle',
              hintText: 'Datenquelle suchen oder auswählen',
              helperText: 'Woraus das Feld aus dem Vorgang vorbelegt wird.',
              helperMaxLines: 2,
              entries: [
                for (final quelle in FeldDatenquelle.values)
                  SearchableDropdownEntry(
                    value: quelle,
                    label: quelle.displayName,
                  ),
              ],
              onChanged: (wert) =>
                  setState(() => _datenquelle = wert ?? _datenquelle),
            ),
            CheckboxListTile(
              value: _erforderlich,
              onChanged: (wert) =>
                  setState(() => _erforderlich = wert ?? _erforderlich),
              title: const Text('Erforderlich'),
              subtitle: const Text(
                'Solange das Feld leer ist, bleibt der Knopf zum Erzeugen '
                'gesperrt.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _speichern,
          child: const Text('Vorlage speichern'),
        ),
      ],
    );
  }
}
