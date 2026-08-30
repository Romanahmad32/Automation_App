import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Auswahl eines Ordners: schreibgeschütztes Pfadfeld plus ein Knopf, der den
/// nativen Ordnerdialog öffnet. Der Pfad wird nicht frei getippt, damit kein
/// ungültiger oder nicht vorhandener Ordner gespeichert wird.
///
/// Aus [StammordnerField] herausgelöst, als der Register-Spiegel ein zweites
/// solches Feld brauchte (§6.2): Zwei Fassungen desselben Feldes hätten sich
/// beim ersten Nachbessern auseinanderentwickelt.
///
/// Zustandsbehaftet allein wegen des [TextEditingController]. Er entstand
/// vorher im `build` und wurde nie freigegeben — bei jedem Neuzeichnen einer:
/// Ein Controller ist ein [ChangeNotifier] und hängt an einem Widget, das ihn
/// abonniert. Das fiel nicht auf, weil das Feld schreibgeschützt ist und der
/// weggeworfene Controller sich unauffällig verhält; gezählt hat es trotzdem,
/// und mit dem Register-Spiegel steht das Feld nun zweimal im selben Formular.
class OrdnerAuswahlFeld extends StatefulWidget {
  final String formControlName;
  final String beschriftung;
  final String dialogTitel;

  /// Steht klein unter dem Feld, solange kein Ordner gewählt ist — die Stelle,
  /// an der erklärt wird, was ohne ihn nicht geht.
  final String hinweisOhneOrdner;

  final IconData icon;

  const OrdnerAuswahlFeld({
    super.key,
    required this.formControlName,
    required this.beschriftung,
    required this.dialogTitel,
    required this.hinweisOhneOrdner,
    this.icon = Icons.folder_outlined,
  });

  @override
  State<OrdnerAuswahlFeld> createState() => OrdnerAuswahlFeldState();
}

class OrdnerAuswahlFeldState extends State<OrdnerAuswahlFeld> {
  final TextEditingController _pfadfeld = TextEditingController();

  @override
  void dispose() {
    _pfadfeld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: widget.formControlName,
      builder: (context, control, _) {
        final pfad = (control.value ?? '').trim();
        // Das Feld zeigt nur an und nimmt keine Eingabe entgegen — den Text
        // hier zu setzen kann deshalb nichts überschreiben, was jemand tippt.
        if (_pfadfeld.text != pfad) _pfadfeld.text = pfad;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: _pfadfeld,
                    decoration: InputDecoration(
                      labelText: widget.beschriftung,
                      hintText: 'Noch kein Ordner gewählt',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(widget.icon),
                      suffixIcon: pfad.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Ordner entfernen',
                              onPressed: () => control.value = '',
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final gewaehlt = await FilePicker.getDirectoryPath(
                      dialogTitle: widget.dialogTitel,
                    );
                    if (gewaehlt != null) control.value = gewaehlt;
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Ordner wählen'),
                ),
              ],
            ),
            if (pfad.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.hinweisOhneOrdner,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
