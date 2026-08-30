import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_file_slot_card.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die beiden Datei-Karten (ohne/mit Auflistung) der Vorlagen-Detailseite.
///
/// Sitzt in einem [ReactiveFormConsumer], weil die Chips die **aktuell
/// eingetragenen** Feldnamen brauchen (Optik „übernommen", Zählzeile): Die
/// Namen leben in den Formular-Controls, und wer hier tippt, soll die Chips
/// mitwandern sehen — ein bloßes setState der Seite bekäme das nicht mit.
class TemplateFileSlots extends StatelessWidget {
  final String? pfadOhneAuflistung;
  final String? pfadMitAuflistung;

  /// Die Felder der Seite; ihr `label` ist der Control-Schlüssel, unter dem
  /// der Feldname liegt (siehe FEATURE.md).
  final List<FieldData> fields;

  final void Function(TemplateFileSlot slot) onPick;
  final void Function(TemplateFileSlot slot) onRemove;
  final ValueChanged<String> onPlaceholderSelected;
  final void Function(List<String> placeholders) onAlleUebernehmen;

  const TemplateFileSlots({
    super.key,
    required this.pfadOhneAuflistung,
    required this.pfadMitAuflistung,
    required this.fields,
    required this.onPick,
    required this.onRemove,
    required this.onPlaceholderSelected,
    required this.onAlleUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveFormConsumer(
      builder: (context, formGroup, child) {
        final vorhandeneNamen = [
          for (final field in fields)
            formGroup.control(field.label).value as String?,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TemplateFileSlotCard(
              slot: TemplateFileSlot.ohneAuflistung,
              path: pfadOhneAuflistung,
              title: 'Vorlage ohne Auflistung (HGN)',
              subtitle:
                  'Standardbrief mit Haftung dem Grunde nach – ohne '
                  'Schadensaufstellung.',
              onPick: () => onPick(TemplateFileSlot.ohneAuflistung),
              onRemove: () => onRemove(TemplateFileSlot.ohneAuflistung),
              onPlaceholderSelected: onPlaceholderSelected,
              vorhandeneNamen: vorhandeneNamen,
              onAlleUebernehmen: onAlleUebernehmen,
            ),
            TemplateFileSlotCard(
              slot: TemplateFileSlot.mitAuflistung,
              path: pfadMitAuflistung,
              title: 'Vorlage mit Auflistung (Schadensaufstellung)',
              subtitle:
                  'Enthält {{Schadensaufstellung}}; beim Ausfüllen wird '
                  'ein zusätzlicher Schritt für die Schadenspositionen '
                  'und die RVG-Kostenberechnung angezeigt.',
              onPick: () => onPick(TemplateFileSlot.mitAuflistung),
              onRemove: () => onRemove(TemplateFileSlot.mitAuflistung),
              onPlaceholderSelected: onPlaceholderSelected,
              vorhandeneNamen: vorhandeneNamen,
              onAlleUebernehmen: onAlleUebernehmen,
            ),
          ],
        );
      },
    );
  }
}
