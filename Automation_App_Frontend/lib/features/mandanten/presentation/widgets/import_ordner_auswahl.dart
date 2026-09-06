import 'package:automation_app/core/general_widgets/form/texte_listen_editor.dart';
import 'package:flutter/material.dart';

/// Die Akten-Ordner einer Importzeile: das Vorhandene als löschbare Chips, ein
/// Suchfeld darunter, das **nur aus dem gescannten Bestand** wählen lässt.
///
/// Der Grund ist die Herkunft der Datei. Sie kommt von einem Programm, das
/// einen Ordnernamen erfinden, verschreiben oder aus einem Aktentext ableiten
/// kann, der nie so auf der Platte stand. Frei getippt landete derselbe Fehler
/// hier ein zweites Mal — ausgerechnet an der Stelle, die ihn beheben soll.
/// Ausgewählt statt getippt schließt das aus, und die Schreibweise stimmt
/// nebenbei zeichengenau mit der Platte überein.
class ImportOrdnerAuswahl extends StatefulWidget {
  /// Wie viele Vorschläge das Feld höchstens anbietet. Unter dem Stammordner
  /// liegen rund viertausend Ordner; eine Liste, die alle zeigt, ist keine
  /// Hilfe, sondern nur eine zweite Suche.
  static const int hoechsteVorschlaege = 20;

  /// Die Ordner, die dieser Zeile bereits zugeschrieben sind.
  final List<String> initialOrdnernamen;

  /// Der gescannte Bestand unter dem Stammordner. **Leer heißt: kein Scan** —
  /// dann bleibt das Feld frei bedienbar (siehe [build]).
  final List<String> vorhandeneOrdner;

  /// Wird bei jeder Änderung mit der vollständigen, aktuellen Liste aufgerufen.
  final ValueChanged<List<String>> onChanged;

  const ImportOrdnerAuswahl({
    super.key,
    required this.initialOrdnernamen,
    required this.vorhandeneOrdner,
    required this.onChanged,
  });

  @override
  State<ImportOrdnerAuswahl> createState() => _ImportOrdnerAuswahlState();
}

class _ImportOrdnerAuswahlState extends State<ImportOrdnerAuswahl> {
  late final List<String> _werte = List.of(widget.initialOrdnernamen);

  /// Das Feld des [Autocomplete]. Es gehört dem Widget darunter; gehalten wird
  /// es nur, um es nach einer Auswahl zu leeren.
  TextEditingController? _feld;

  @override
  Widget build(BuildContext context) {
    // Ohne Scan bleibt das Feld, wie es war — freie Eingabe über den
    // vorhandenen Editor. Ein Stammordner, der nicht eingerichtet ist oder auf
    // einem gerade nicht erreichbaren Netzlaufwerk liegt, darf den Import nicht
    // unbenutzbar machen: die Datei ist deshalb nicht schlechter, und die
    // Übernahme sperrt aus demselben Grund auch nicht (`OrdnerPruefung`).
    if (widget.vorhandeneOrdner.isEmpty) {
      return TexteListenEditor(
        initialWerte: widget.initialOrdnernamen,
        onChanged: widget.onChanged,
        labelText: 'Akten-Ordner',
        helperText: 'Nur der Ordnername unter dem Stammordner, kein Pfad',
        chipIcon: Icons.folder_outlined,
        entfernenTooltip: 'Ordner aus dieser Zeile nehmen',
        hinzufuegenTooltip: 'Ordner hinzufügen',
        dublettenHinweis: 'Dieser Ordner steht bereits in der Zeile',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_werte.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wert in _werte)
                  Chip(
                    avatar: const Icon(Icons.folder_outlined, size: 18),
                    label: Text(wert),
                    onDeleted: () => _entfernen(wert),
                    deleteButtonTooltipMessage:
                        'Ordner aus dieser Zeile nehmen',
                  ),
              ],
            ),
          ),
        Autocomplete<String>(
          optionsBuilder: _vorschlaege,
          onSelected: _aufnehmen,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _feld = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onFieldSubmitted(),
              decoration: const InputDecoration(
                labelText: 'Akten-Ordner',
                helperText:
                    'Tippen und aus dem Stammordner auswählen — nur '
                    'vorhandene Ordner',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_open_outlined),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Was zur Eingabe passt, ohne die schon gewählten Ordner. Ein leeres Feld
  /// schlägt nichts vor: viertausend Namen sind keine Auswahl.
  Iterable<String> _vorschlaege(TextEditingValue eingabe) {
    final gesucht = eingabe.text.trim().toLowerCase();
    if (gesucht.isEmpty) return const Iterable<String>.empty();
    return widget.vorhandeneOrdner
        .where(
          (ordner) =>
              ordner.toLowerCase().contains(gesucht) && !_enthaelt(ordner),
        )
        .take(ImportOrdnerAuswahl.hoechsteVorschlaege);
  }

  bool _enthaelt(String ordner) =>
      _werte.any((wert) => wert.toLowerCase() == ordner.toLowerCase());

  void _aufnehmen(String ordner) {
    setState(() {
      _werte.add(ordner);
      _feld?.clear();
    });
    widget.onChanged(List.unmodifiable(_werte));
  }

  void _entfernen(String ordner) {
    setState(() => _werte.remove(ordner));
    widget.onChanged(List.unmodifiable(_werte));
  }
}
