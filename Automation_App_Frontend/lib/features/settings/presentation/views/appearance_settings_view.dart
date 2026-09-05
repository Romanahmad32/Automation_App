import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Einstellungen zur Darstellung: Auswahl der Theme-Familie (Kanzlei-Design /
/// Standard), des Hell-/Dunkel-/System-Modus und des Schriftgrads. Liest und
/// schreibt den global bereitgestellten [ThemeBloc]; jede Auswahl wird sofort
/// angewendet und persistiert.
class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final bloc = context.read<ThemeBloc>();
        // Kein Speichern-Knopf in der Kopfzeile: Alle Auswahlen gelten sofort
        // und werden sofort abgelegt.
        //
        // Links steht das Design, rechts die beiden Einstellungen, die „für
        // beide Designs" gelten — Helligkeit und Schriftgrad gehören
        // zusammen: Sie ändern nicht das Markenbild, sondern die Lesbarkeit.
        return EinstellungenReiter(
          links: [
            FormSection(
              icon: Icons.palette_outlined,
              title: 'Design',
              subtitle:
                  'Bestimmt das gesamte Erscheinungsbild der App. '
                  '"Kanzlei-Design" ist das warme Bordeaux-Markenbild, '
                  '"Standard" das klassische blaue Theme.',
              children: [
                SegmentedButton<AppThemeVariant>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeVariant.kanzlei,
                      icon: Icon(Icons.brightness_1),
                      label: Text('Kanzlei-Design'),
                    ),
                    ButtonSegment(
                      value: AppThemeVariant.standard,
                      icon: Icon(Icons.brightness_1_outlined),
                      label: Text('Standard'),
                    ),
                  ],
                  selected: {state.variant},
                  onSelectionChanged: (selection) =>
                      bloc.add(ChangeThemeVariantEvent(selection.first)),
                ),
              ],
            ),
          ],
          rechts: [
            FormSection(
              icon: Icons.brightness_6_outlined,
              title: 'Hell / Dunkel',
              subtitle:
                  'Gilt für beide Designs. "System" folgt der '
                  'Windows-Einstellung.',
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Hell'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dunkel'),
                    ),
                  ],
                  selected: {state.mode},
                  onSelectionChanged: (selection) =>
                      bloc.add(ChangeThemeModeEvent(selection.first)),
                ),
              ],
            ),
            FormSection(
              icon: Icons.format_size,
              title: 'Schriftgröße',
              subtitle:
                  'Gilt für die ganze Oberfläche und wirkt sofort. '
                  '"Größer" ist die Vorgabe.',
              children: [
                SegmentedButton<Schriftstufe>(
                  segments: [
                    // Die Beschriftungen kommen aus der Aufzählung, nicht aus
                    // Literalen hier: Sonst hieße dieselbe Stufe an der
                    // nächsten Stelle anders.
                    ButtonSegment(
                      value: Schriftstufe.normal,
                      icon: const Icon(Icons.text_decrease),
                      label: Text(Schriftstufe.normal.bezeichnung),
                    ),
                    ButtonSegment(
                      value: Schriftstufe.groesser,
                      icon: const Icon(Icons.text_fields),
                      label: Text(Schriftstufe.groesser.bezeichnung),
                    ),
                    ButtonSegment(
                      value: Schriftstufe.amGroessten,
                      icon: const Icon(Icons.text_increase),
                      label: Text(Schriftstufe.amGroessten.bezeichnung),
                    ),
                  ],
                  selected: {state.schriftstufe},
                  onSelectionChanged: (selection) =>
                      bloc.add(ChangeSchriftstufeEvent(selection.first)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
