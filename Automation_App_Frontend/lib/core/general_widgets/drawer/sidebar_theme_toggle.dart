import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schnellschalter zwischen hellem und dunklem Erscheinungsbild im Fuß der
/// Seitenleiste.
class SidebarThemeToggle extends StatelessWidget {
  const SidebarThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        // Anhand der tatsächlich aktiven Helligkeit umschalten, damit der
        // Schnellschalter auch im Systemmodus das Erwartete tut.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return IconButton(
          onPressed: () {
            context.read<ThemeBloc>().add(
              ChangeThemeModeEvent(isDark ? ThemeMode.light : ThemeMode.dark),
            );
          },
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: isDark ? 'Hell' : 'Dunkel',
        );
      },
    );
  }
}
