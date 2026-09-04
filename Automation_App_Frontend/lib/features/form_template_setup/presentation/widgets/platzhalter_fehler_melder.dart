import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Meldet Fehler beim Lesen einer Word-Datei (z. B. Datei in Word geöffnet)
/// über [Rueckmeldung] — zusätzlich zum Inline-Text in der Platzhalter-Box.
///
/// Braucht keine eigene Dublettenprüfung mehr (Issue #56): Liefert der Bloc
/// denselben Fehlerzustand erneut aus — etwa weil der andere Slot sich ändert
/// und die ganze Zustandsliste neu emittiert wird —, erkennt
/// `RueckmeldungsInhalt.gleichWie` dieselbe stehende Meldung und startet nur
/// ihren Timer neu, statt sie zu verdoppeln.
class PlatzhalterFehlerMelder extends StatelessWidget {
  final Widget child;

  const PlatzhalterFehlerMelder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
      listener: (context, state) {
        for (final slot in TemplateFileSlot.values) {
          final result = state.forSlot(slot);
          if (result is SlotPlaceholdersError) {
            Rueckmeldung.zeigeFehler(context, result.message);
          }
        }
      },
      child: child,
    );
  }
}
