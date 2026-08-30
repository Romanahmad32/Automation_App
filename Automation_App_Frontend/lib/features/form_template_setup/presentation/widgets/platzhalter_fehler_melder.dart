import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Meldet Fehler beim Lesen einer Word-Datei (z. B. Datei in Word geöffnet)
/// als Snackbar — zusätzlich zum Inline-Text in der Platzhalter-Box.
class PlatzhalterFehlerMelder extends StatefulWidget {
  final Widget child;

  const PlatzhalterFehlerMelder({super.key, required this.child});

  @override
  State<PlatzhalterFehlerMelder> createState() =>
      _PlatzhalterFehlerMelderState();
}

class _PlatzhalterFehlerMelderState extends State<PlatzhalterFehlerMelder> {
  // Zuletzt je Slot angezeigte Fehlermeldung, um Snackbar-Wiederholungen
  // bei jedem Rebuild zu vermeiden.
  final Map<TemplateFileSlot, String?> _lastErrorShown = {};

  @override
  Widget build(BuildContext context) {
    return BlocListener<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      listener: (context, state) {
        for (final slot in TemplateFileSlot.values) {
          final result = state.forSlot(slot);
          final message = result is SlotPlaceholdersError
              ? result.message
              : null;
          if (message != null && _lastErrorShown[slot] != message) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
          _lastErrorShown[slot] = message;
        }
      },
      child: widget.child,
    );
  }
}
