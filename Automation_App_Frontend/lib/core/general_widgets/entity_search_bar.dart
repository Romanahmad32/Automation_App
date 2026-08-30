import 'dart:async';

import 'package:flutter/material.dart';

/// Wiederverwendbares Suchfeld mit eigenem Controller (verhindert
/// Cursor-Sprünge beim erneuten Aufbau) und Löschknopf. Die Filterlogik bleibt
/// beim Aufrufer: Eingaben werden über [onChanged] gemeldet.
class EntitySearchBar extends StatefulWidget {
  final String initialQuery;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Wartezeit, bevor eine Eingabe gemeldet wird. Vorgabe ist keine — wer im
  /// Speicher filtert, will jeden Tastendruck sofort sehen.
  ///
  /// Geht die Suche dagegen an den Dienst, wäre „Mustermann" sonst zehn
  /// Abrufe für ein Ergebnis; dann gehört hier eine kurze Wartezeit hin. Sie
  /// steht im Suchfeld und nicht im Bloc, weil ein Bloc-Transformer aus
  /// `bloc_concurrency` die Teardown von Widget-Tests aufhängt: `close()`
  /// wartet dort auf ein Abbestellen, das in der abgelaufenen Fake-Async-Zone
  /// nicht mehr durchläuft.
  final Duration entprellung;

  const EntitySearchBar({
    super.key,
    required this.initialQuery,
    required this.hintText,
    required this.onChanged,
    this.entprellung = Duration.zero,
  });

  @override
  State<EntitySearchBar> createState() => _EntitySearchBarState();
}

class _EntitySearchBarState extends State<EntitySearchBar> {
  late final TextEditingController _controller;
  Timer? _wartet;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _wartet?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Eine Eingabe melden — nach der Wartezeit, und nur die letzte.
  void _melden(String wert) {
    _wartet?.cancel();
    if (widget.entprellung == Duration.zero) {
      widget.onChanged(wert);
      return;
    }
    _wartet = Timer(widget.entprellung, () => widget.onChanged(wert));
  }

  /// Das Löschen ist keine Eingabe, sondern eine Entscheidung — es gilt sofort.
  void _leeren() {
    _wartet?.cancel();
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _melden,
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
              onPressed: _leeren,
            );
          },
        ),
      ),
    );
  }
}
