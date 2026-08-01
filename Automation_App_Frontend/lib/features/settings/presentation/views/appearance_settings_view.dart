import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Einstellungen zur Darstellung: Auswahl der Theme-Familie (Kanzlei-Design /
/// Standard) und des Hell-/Dunkel-/System-Modus. Liest und schreibt den global
/// bereitgestellten [ThemeBloc]; die Auswahl wird sofort angewendet und
/// persistiert.
class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        final bloc = context.read<ThemeBloc>();
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    FormSection(
                      icon: Icons.palette_outlined,
                      title: 'Design',
                      subtitle:
                          'Bestimmt das gesamte Erscheinungsbild der App. '
                          '"Kanzlei-Design" ist das warme Bordeaux-Markenbild, '
                          '"Standard" das klassische blaue Theme.',
                      children: [
                        SegmentedButton<AppThemeVariant>(
                          showSelectedIcon: false,
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
                          onSelectionChanged: (selection) => bloc.add(
                            ChangeThemeVariantEvent(selection.first),
                          ),
                        ),
                      ],
                    ),
                    FormSection(
                      icon: Icons.brightness_6_outlined,
                      title: 'Hell / Dunkel',
                      subtitle:
                          'Gilt für beide Designs. "System" folgt der '
                          'Windows-Einstellung.',
                      children: [
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
