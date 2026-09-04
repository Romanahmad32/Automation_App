import 'package:flutter/material.dart';

/// Editor für eine Liste kurzer Texte: das Vorhandene als löschbare Chips, ein
/// Eingabefeld zum Hinzufügen darunter.
///
/// Entstanden aus dem `KennzeichenEditor`, als die Importvorschau dieselbe
/// Bauform für die Akten-Ordnernamen brauchte. Was sich zwischen beiden
/// unterscheidet, ist nur Beschriftung und Prüfung — beides steckt in den
/// Parametern, damit nicht zwei Fassungen derselben Liste nebeneinander
/// altern.
class TexteListenEditor extends StatefulWidget {
  /// Ausgangswerte.
  final List<String> initialWerte;

  /// Wird bei jeder Änderung mit der vollständigen, aktuellen Liste aufgerufen.
  final ValueChanged<List<String>> onChanged;

  final String labelText;
  final String? helperText;
  final IconData chipIcon;
  final String entfernenTooltip;
  final String hinzufuegenTooltip;
  final TextCapitalization textCapitalization;

  /// Bringt eine Eingabe in die Schreibweise ihres Fachs (z. B. `hge1427` →
  /// `HG-E 1427`), **bevor** [pruefe], der Dublettenvergleich und die Aufnahme
  /// in die Liste sie sehen. Ohne Angabe wird die Eingabe nur gestutzt.
  ///
  /// Diese Reihenfolge ist der Zweck: Sonst beanstandete die Prüfung eine
  /// Schreibvariante, die der Editor gleich darauf selbst geradegezogen hätte,
  /// und derselbe Wagen stünde zweimal in der Liste — einmal als `HG-E 1427`,
  /// einmal als `hge1427`.
  final String Function(String eingabe)? normalisiere;

  /// Prüft eine Eingabe vor dem Aufnehmen: `null` heißt in Ordnung, sonst ist
  /// das Ergebnis die Meldung am Feld.
  final String? Function(String eingabe)? pruefe;

  /// Meldung, wenn der Wert schon in der Liste steht.
  final String dublettenHinweis;

  const TexteListenEditor({
    super.key,
    required this.initialWerte,
    required this.onChanged,
    required this.labelText,
    required this.chipIcon,
    required this.entfernenTooltip,
    required this.hinzufuegenTooltip,
    this.helperText,
    this.textCapitalization = TextCapitalization.sentences,
    this.normalisiere,
    this.pruefe,
    this.dublettenHinweis = 'Dieser Eintrag steht bereits in der Liste',
  });

  @override
  State<TexteListenEditor> createState() => _TexteListenEditorState();
}

class _TexteListenEditorState extends State<TexteListenEditor> {
  late final List<String> _werte = List.of(widget.initialWerte);
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _fehler;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _hinzufuegen() {
    final getippt = _controller.text.trim();
    final eingabe = widget.normalisiere?.call(getippt) ?? getippt;
    if (eingabe.isEmpty) {
      setState(() => _fehler = null);
      return;
    }

    final beanstandung = widget.pruefe?.call(eingabe);
    if (beanstandung != null) {
      setState(() => _fehler = beanstandung);
      return;
    }
    if (_werte.any((w) => w.toLowerCase() == eingabe.toLowerCase())) {
      setState(() => _fehler = widget.dublettenHinweis);
      return;
    }

    setState(() {
      _werte.add(eingabe);
      _controller.clear();
      _fehler = null;
    });
    widget.onChanged(List.unmodifiable(_werte));
    _focusNode.requestFocus();
  }

  void _entfernen(String wert) {
    setState(() => _werte.remove(wert));
    widget.onChanged(List.unmodifiable(_werte));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    avatar: Icon(widget.chipIcon, size: 18),
                    label: Text(wert),
                    onDeleted: () => _entfernen(wert),
                    deleteButtonTooltipMessage: widget.entfernenTooltip,
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: widget.textCapitalization,
                onSubmitted: (_) => _hinzufuegen(),
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  helperText: widget.helperText,
                  errorText: _fehler,
                  border:
                      theme.inputDecorationTheme.border ??
                      const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                onPressed: _hinzufuegen,
                icon: const Icon(Icons.add),
                tooltip: widget.hinzufuegenTooltip,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
