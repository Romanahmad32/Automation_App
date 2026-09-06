import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slot_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';

/// Die beiden Datei-Karten (ohne/mit Auflistung) der Vorlagen-Detailseite.
///
/// **Gleichwertig**: Keiner der beiden Slots ist der Regelfall und keiner
/// „optional" — welche Datei eine Vorlage braucht, entscheidet der Fall, und
/// `VorlagenStandKarte` wertet einen leeren Slot ausdrücklich nicht als Mangel
/// (siehe `FALLSTRICKE.md`).
///
/// Der [ReactiveFormConsumer], der hier bis Stufe 3a saß, ist weg: Er trug die
/// aktuell eingetragenen Feldnamen zu den Chips, und die Chips stehen jetzt im
/// `PlatzhalterAbschnitt` (#104). Übrig bleiben die beiden Word-Pfade — die
/// liegen im Zustand der Seite und kommen mit deren `setState` an.
class TemplateFileSlots extends StatelessWidget {
  /// Der Stand des Editors: die beiden Word-Pfade.
  final VorlagenBearbeitung bearbeitung;

  final void Function(TemplateFileSlot slot) onPick;
  final void Function(TemplateFileSlot slot) onRemove;

  const TemplateFileSlots({
    super.key,
    required this.bearbeitung,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TemplateFileSlotCard(
          slot: TemplateFileSlot.ohneAuflistung,
          path: bearbeitung.pfadOhneAuflistung,
          title: 'Vorlage ohne Auflistung (HGn)',
          subtitle:
              'Standardbrief mit Haftung dem Grunde nach – ohne '
              'Schadensaufstellung.',
          onPick: () => onPick(TemplateFileSlot.ohneAuflistung),
          onRemove: () => onRemove(TemplateFileSlot.ohneAuflistung),
        ),
        TemplateFileSlotCard(
          slot: TemplateFileSlot.mitAuflistung,
          path: bearbeitung.pfadMitAuflistung,
          title: 'Vorlage mit Auflistung (Schadensaufstellung)',
          subtitle:
              'Enthält {{Schadensaufstellung}}; beim Ausfüllen wird '
              'ein zusätzlicher Schritt für die Schadenspositionen '
              'und die RVG-Kostenberechnung angezeigt.',
          onPick: () => onPick(TemplateFileSlot.mitAuflistung),
          onRemove: () => onRemove(TemplateFileSlot.mitAuflistung),
        ),
      ],
    );
  }
}
