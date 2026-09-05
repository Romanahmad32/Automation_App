import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/settings/presentation/views/appearance_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/theme/theme_doubles.dart';

/// Der Reiter „Darstellung" hat seit Issue #57 eine dritte Auswahl: die
/// Schriftgröße. Sie ist die einzige der drei, die die Größe **des Reiters
/// selbst** verändert — er zeigt an, was er einstellt.
///
/// Geprüft wird die Kette Knopf → Bloc, nicht das Aussehen: Ein
/// `SegmentedButton` ohne `onSelectionChanged` sieht bedienbar aus, färbt beim
/// Tippen aber nichts um und schreibt nichts fort. Diesen Ausfall sieht man
/// einer Ansicht nicht an — er fällt erst auf, wenn der Anwalt die App neu
/// startet und alles wieder so groß ist wie vorher.
void main() {
  late MerkenderThemeSpeicher speicher;
  late ThemeBloc bloc;

  /// Ohne `DefaultTabController` darum: Die Abschnittswahl in der Kopfzeile
  /// bleibt dann weg, der Reiter selbst bleibt bedienbar (siehe
  /// `einstellungen_reiter_test.dart` und den Steckbrief des Features).
  Future<void> zeige(WidgetTester tester) async {
    speicher = MerkenderThemeSpeicher();
    bloc = ThemeBloc(speicher);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        // Dasselbe Theme wie im Betrieb, damit die Karten und der
        // SegmentedButton ihre echten Größen bekommen.
        theme: MaterialTheme(ThemeData.light().textTheme).light(),
        home: BlocProvider<ThemeBloc>.value(
          value: bloc,
          child: const Scaffold(body: AppearanceSettingsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Die Schriftgröße ist die dritte Karte des Reiters und liegt im
  /// 800×600-Testfenster unterhalb des Rands — ein blanker `tap` träfe die
  /// leere Fläche darunter und meldete das nur als Warnung.
  Future<void> tippe(WidgetTester tester, String beschriftung) async {
    final knopf = find.text(beschriftung);
    await tester.ensureVisible(knopf);
    await tester.pumpAndSettle();
    await tester.tap(knopf);
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt die drei Stufen mit der Vorgabe ausgewaehlt', (
    tester,
  ) async {
    await zeige(tester);

    for (final stufe in Schriftstufe.values) {
      expect(find.text(stufe.bezeichnung), findsOneWidget);
    }

    final knopf = tester.widget<SegmentedButton<Schriftstufe>>(
      find.byType(SegmentedButton<Schriftstufe>),
    );
    expect(knopf.selected, {Schriftstufe.vorgabe});
  });

  testWidgets('ein Tipp auf "Am groessten" stellt die Schrift um', (
    tester,
  ) async {
    await zeige(tester);

    await tippe(tester, Schriftstufe.amGroessten.bezeichnung);

    expect(bloc.state.schriftstufe, Schriftstufe.amGroessten);
    expect(
      speicher.gespeichert.single.schriftstufe,
      Schriftstufe.amGroessten,
      reason:
          'Kein Speichern-Knopf im Reiter — die Auswahl muss von selbst in '
          'der Datei landen, sonst ist sie beim nächsten Start weg.',
    );

    final knopf = tester.widget<SegmentedButton<Schriftstufe>>(
      find.byType(SegmentedButton<Schriftstufe>),
    );
    expect(knopf.selected, {
      Schriftstufe.amGroessten,
    }, reason: 'Der Reiter liest seinen Stand aus dem Bloc zurück.');
  });

  testWidgets('die Wahl laesst Design und Hell/Dunkel stehen', (tester) async {
    await zeige(tester);

    await tippe(tester, 'Standard');
    await tippe(tester, Schriftstufe.normal.bezeichnung);

    expect(bloc.state.variant, AppThemeVariant.standard);
    expect(bloc.state.schriftstufe, Schriftstufe.normal);
  });
}
