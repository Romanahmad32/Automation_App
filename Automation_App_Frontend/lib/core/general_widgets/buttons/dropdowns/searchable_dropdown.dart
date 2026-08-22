import 'package:flutter/material.dart';

/// Ein Eintrag des [SearchableDropdown]: der Wert plus das angezeigte Label,
/// nach dem auch live gefiltert wird.
class SearchableDropdownEntry<T> {
  final T value;
  final String label;

  const SearchableDropdownEntry({required this.value, required this.label});
}

/// Durchsuchbares Auswahlfeld im Look der übrigen Formularfelder
/// (OutlineInputBorder + Label) — analog zur Formularvorlage-Auswahl
/// (`TemplateSelector`). Tippen filtert die Einträge live nach ihrem Label.
///
/// Generisch über den Werttyp [T]; die Auswahl wird per Wert-Gleichheit mit
/// [entries] abgeglichen. Für `reactive_forms`-Formulare gibt es den Wrapper
/// `ReactiveSearchableDropdown`.
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<SearchableDropdownEntry<T>> entries;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final String hintText;
  final String? helperText;
  final int? helperMaxLines;
  final Widget? leadingIcon;
  final InputBorder border;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.labelText,
    this.hintText = 'Suchen oder auswählen',
    this.helperText,
    this.helperMaxLines,
    this.leadingIcon,
    this.border = const OutlineInputBorder(),
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = _labelFor(widget.value) ?? '';
    // Verlässt der Fokus das Feld ohne Auswahl, bliebe sonst der getippte
    // Filtertext stehen; stattdessen das Label der Auswahl wiederherstellen.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _syncControllerToValue();
      }
    });
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.entries != widget.entries) {
      _syncControllerToValue();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _labelFor(T? value) {
    for (final entry in widget.entries) {
      if (entry.value == value) {
        return entry.label;
      }
    }
    return null;
  }

  /// Feldtext auf das Label der aktuellen Auswahl setzen — aber nicht mitten
  /// ins Tippen hinein, solange das Feld den Fokus hat.
  void _syncControllerToValue() {
    if (_focusNode.hasFocus) {
      return;
    }
    final label = _labelFor(widget.value) ?? '';
    if (_controller.text != label) {
      _controller.text = label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      controller: _controller,
      focusNode: _focusNode,
      initialSelection: widget.value,
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      label: widget.labelText == null ? null : Text(widget.labelText!),
      hintText: widget.hintText,
      helperText: widget.helperText,
      leadingIcon: widget.leadingIcon,
      inputDecorationTheme: InputDecorationTheme(
        border: widget.border,
        helperMaxLines: widget.helperMaxLines,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dropdownMenuEntries: [
        for (final entry in widget.entries)
          DropdownMenuEntry<T>(value: entry.value, label: entry.label),
      ],
      onSelected: (value) {
        widget.onChanged(value);
        // Filter-Fokus abgeben, damit das Feld das gewählte Label anzeigt
        // und die nächste Öffnung ungefiltert startet.
        _focusNode.unfocus();
      },
    );
  }
}
