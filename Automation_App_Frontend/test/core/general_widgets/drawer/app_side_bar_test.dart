import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/aktualisierung/neue_version.dart';
import 'package:automation_app/core/general_widgets/drawer/app_side_bar.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_hinweis.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../theme/theme_doubles.dart';

/// Die Seitenleiste hat eine feste Breite (`AppShellPage._expandedWidth`, hier
/// als Literal dupliziert, weil sie dort privat ist) — bei der größten
/// Schriftstufe (Issue #57) müssen die Beschriftungen trotzdem hineinpassen.
/// Reproduziert das Überlaufbild aus der Kanzlei: aufgeklappte Leiste,
/// Stufe „Am größten".
void main() {
  const collapsedWidth = 72.0;
  const expandedWidth = 236.0;

  ThemeData amGroesstenTheme() => MaterialTheme(
    ThemeData.light().textTheme,
    schriftstufe: Schriftstufe.amGroessten,
  ).light();

  /// Setzt ein großzügiges Testfenster — die feste Breite kommt ohnehin von
  /// den Parametern der Leiste, nicht vom Fenster; die Höhe muss nur für die
  /// neun Einträge reichen.
  void setzeFenstergroesse(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'die Eintraege laufen bei groesster Schrift nicht ueber die feste Breite',
    (tester) async {
      setzeFenstergroesse(tester);

      // Der Fuß bindet den SidebarThemeToggle ein, der einen ThemeBloc aus
      // dem Kontext liest — ohne Provider bräche der Aufbau schon daran,
      // bevor die eigentliche Überlauffrage überhaupt geprüft wird.
      final themeBloc = ThemeBloc(MerkenderThemeSpeicher());
      addTearDown(themeBloc.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: amGroesstenTheme(),
          home: BlocProvider<ThemeBloc>.value(
            value: themeBloc,
            child: Scaffold(
              body: AppSidebar(
                isExtended: true,
                collapsedWidth: collapsedWidth,
                expandedWidth: expandedWidth,
                animationDuration: Duration.zero,
                activeIndex: 0,
                onDestinationSelected: (_) {},
                onToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die aufgeklappte Leiste hat eine feste Breite (expandedWidth) — '
            'bei „Am größten" dürfen „Word Automation" und „Vorlagen '
            'Verwalten" nicht über den rechten Rand laufen.',
      );
    },
  );

  testWidgets(
    'der Update-Hinweis im Fuss laeuft bei groesster Schrift nicht ueber',
    (tester) async {
      setzeFenstergroesse(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: amGroesstenTheme(),
          home: Scaffold(
            body: SizedBox(
              width: expandedWidth,
              child: const SidebarUpdateHinweis(
                stand: AktualisierungsErgebnis.verfuegbar(
                  NeueVersion(
                    nummer: '1.2.0',
                    seite: 'https://example.invalid',
                  ),
                ),
                isExtended: true,
                collapsedWidth: collapsedWidth,
                animationDuration: Duration.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Der Fuß-Hinweis „Update verfügbar" darf bei „Am größten" nicht '
            'über die feste Leistenbreite laufen.',
      );
    },
  );
}
