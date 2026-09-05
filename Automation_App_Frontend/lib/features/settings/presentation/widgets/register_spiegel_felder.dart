import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// **Was** in der Register-Datei steht und **wann** sie entsteht (§6.2):
/// Dateiname, Schreiben nach Abschluss, Inhaltsfilter.
///
/// Aus `register_ablage_felder.dart` herausgelöst, als aus vier Ordnerwahlen
/// eine wurde (#103): Der Ablageordner wanderte in den Aufklapper
/// „Abweichende Ordner festlegen", diese drei Felder aber sind gar keine
/// Ordnerwahl. Sie dort mit einzuklappen hiesse, eine Einstellung, die jeder
/// treffen will, hinter einer zu verstecken, die fast niemand braucht.
class RegisterSpiegelFelder extends StatelessWidget {
  const RegisterSpiegelFelder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stillerText = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GeneralTextField<String>(
          formControlName: 'registerDateiname',
          labelText: 'Dateiname (ohne Endung)',
          inputDecoration: InputDecoration(
            hintText: KanzleiSettings.defaultRegisterDateiname,
            prefixIcon: Icon(Icons.description_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Daraus entstehen die Word- und die PDF-Fassung. Ein eigener Name ist '
          'Absicht: Das bisherige Register-Dokument der Kanzlei bleibt daneben '
          'unangetastet liegen.',
          style: stillerText,
        ),
        const SizedBox(height: 16),
        ReactiveSwitchListTile(
          formControlName: 'registerNachAbschlussSchreiben',
          title: const Text('Nach jedem Abschluss neu schreiben'),
          subtitle: const Text(
            'Sonst nur auf Knopfdruck im Register. Ein Fehlschlag dabei kann '
            'einen abgeschlossenen Vorgang nie rückgängig machen.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        ReactiveDropdownField<String>(
          formControlName: 'registerExportFilter',
          // Ohne das bestimmt der längste Eintrag die Mindestbreite des Feldes,
          // und das Formular läuft auf schmalen Fenstern seitlich heraus.
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Inhalt der Datei',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: const [
            DropdownMenuItem(
              value: KanzleiSettings.registerFilterAlle,
              child: Text('Alle Vorgänge'),
            ),
            DropdownMenuItem(
              value: KanzleiSettings.registerFilterAbgeschlossen,
              child: Text('Nur abgeschlossene Vorgänge'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Bewusst hier und nicht im Register: Der Filter dort wirkt nur auf den '
          'Bildschirm. Sonst hinge der Inhalt einer Datei, die andere lesen, '
          'davon ab, was zuletzt eingestellt war.',
          style: stillerText,
        ),
      ],
    );
  }
}
