import 'package:flutter/material.dart';

/// Wiederverwendbares Suchfeld mit eigenem Controller (verhindert
/// Cursor-Sprünge beim erneuten Aufbau) und Löschknopf. Die Filterlogik bleibt
/// beim Aufrufer: Eingaben werden über [onChanged] gemeldet.
class EntitySearchBar extends StatefulWidget {
  final String initialQuery;
  final String hintText;
  final ValueChanged<String> onChanged;

  const EntitySearchBar({
    super.key,
    required this.initialQuery,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<EntitySearchBar> createState() => _EntitySearchBarState();
}

class _EntitySearchBarState extends State<EntitySearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Suche zurücksetzen',
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            );
          },
        ),
      ),
    );
  }
}
