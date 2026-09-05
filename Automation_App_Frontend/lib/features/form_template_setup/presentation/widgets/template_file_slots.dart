import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slot_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die beiden Datei-Karten (ohne/mit Auflistung) der Vorlagen-Detailseite.
///
/// Sitzt in einem [ReactiveFormConsumer], weil die Chips die **aktuell
/// eingetragenen** Feldnamen brauchen (Optik „übernommen"): Die Namen leben in
/// den Formular-Controls, und wer hier tippt, soll die Chips mitwandern sehen
/// — ein bloßes setState der Seite bekäme das nicht mit.
class TemplateFileSlots extends StatelessWidget {
  /// Der Stand des Editors: die beiden Word-Pfade und die Felder, deren
  /// `label` der Control-Schlüssel ist (siehe FEATURE.md).
  final VorlagenBearbeitung bearbeitung;

  final void Function(TemplateFileSlot slot) onPick;
  final void Function(TemplateFileSlot slot) onRemove;
  final ValueChanged<String> onPlaceholderSelected;

  const TemplateFileSlots({
    super.key,
    required this.bearbeitung,
    required this.onPick,
    required this.onRemove,
    required this.onPlaceholderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        final vorhandeneNamen = bearbeitung.feldnamen;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TemplateFileSlotCard(
              slot: TemplateFileSlot.ohneAuflistung,
              path: bearbeitung.pfadOhneAuflistung,
              title: 'Vorlage ohne Auflistung (HGN)',
              subtitle:
                  'Standardbrief mit Haftung dem Grunde nach – ohne '
                  'Schadensaufstellung.',
              onPick: () => onPick(TemplateFileSlot.ohneAuflistung),
              onRemove: () => onRemove(TemplateFileSlot.ohneAuflistung),
              onPlaceholderSelected: onPlaceholderSelected,
              vorhandeneNamen: vorhandeneNamen,
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
              onPlaceholderSelected: onPlaceholderSelected,
              vorhandeneNamen: vorhandeneNamen,
            ),
          ],
        );
      },
    );
  }
}
