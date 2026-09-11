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

  /// Bringt eine Eingabe in die Schreibweise ihres Fachs, **bevor** [pruefe],
  /// der Dublettenvergleich und die Aufnahme in die Liste sie sehen. Ohne
  /// Angabe wird die Eingabe nur gestutzt.
  ///
  /// Diese Reihenfolge ist der Zweck: Sonst beanstandete die Prüfung eine
  /// Schreibvariante, die der Editor gleich darauf selbst geradegezogen hätte.
  /// Kennzeichen nutzen das nicht mehr — sie werden aufgenommen, wie sie
  /// getippt wurden (§4.2), und über [gleich] als Dublette erkannt.
  final String Function(String eingabe)? normalisiere;

  /// Prüft eine Eingabe vor dem Aufnehmen: `null` heißt in Ordnung, sonst ist
  /// das Ergebnis die Meldung am Feld.
  final String? Function(String eingabe)? pruefe;

  /// Was zur **gerade getippten** Eingabe anzumerken ist; `null` heißt: nichts.
  /// Anders als [pruefe] hält das nichts auf — der Text steht als Hinweis unter
  /// dem Feld, in der Aufmerksamkeitsfarbe, und der Wert wird trotzdem
  /// aufgenommen. Für Bestände, in denen die App eine Konvention **kennt**,
  /// aber nicht darüber zu entscheiden hat, was hineingehört (Kennzeichen,
  /// #130).
  final String? Function(String eingabe)? anmerke;

  /// Ob zwei Einträge **dasselbe** meinen — für den Dublettenvergleich. Ohne
  /// Angabe zählt der Text ohne Rücksicht auf Groß- und Kleinschreibung.
  ///
  /// Kennzeichen brauchen mehr: `hge1427` und `HG-E 1427` sind derselbe Wagen,
  /// auch wenn die Liste jeden so aufnimmt, wie er getippt wurde (§4.2). Ohne
  /// diesen Vergleich stünde er zweimal darin.
  final bool Function(String a, String b)? gleich;

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
    this.anmerke,
    this.gleich,
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
    if (_werte.any((w) => _gleich(w, eingabe))) {
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

  bool _gleich(String a, String b) =>
      widget.gleich?.call(a, b) ?? a.toLowerCase() == b.toLowerCase();

  /// Die Anmerkung zur getippten Eingabe — so befragt, wie sie auch
  /// aufgenommen würde (mit [TexteListenEditor.normalisiere], falls gesetzt).
  String? _anmerkung(String getippt) {
    final eingabe = getippt.trim();
    if (eingabe.isEmpty) return null;
    return widget.anmerke?.call(widget.normalisiere?.call(eingabe) ?? eingabe);
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
              // Auf den Text hören, damit die Anmerkung schon beim Tippen
              // steht und nicht erst, wenn jemand „Hinzufügen" drückt.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, wert, child) {
                  final anmerkung = _anmerkung(wert.text);
                  return TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textCapitalization: widget.textCapitalization,
                    onSubmitted: (_) => _hinzufuegen(),
                    decoration: InputDecoration(
                      labelText: widget.labelText,
                      helperText: anmerkung ?? widget.helperText,
                      helperMaxLines: anmerkung == null ? null : 2,
                      helperStyle: anmerkung == null
                          ? null
                          : TextStyle(color: theme.colorScheme.tertiary),
                      errorText: _fehler,
                      border:
                          theme.inputDecorationTheme.border ??
                          const OutlineInputBorder(),
                    ),
                  );
                },
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
