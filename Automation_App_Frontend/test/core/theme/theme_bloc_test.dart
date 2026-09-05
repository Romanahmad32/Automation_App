import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_doubles.dart';

/// Der Schriftgrad ist die dritte Einstellung im Reiter „Darstellung"
/// (Issue #57) und läuft denselben Weg wie Design und Hell/Dunkel: sofort
/// anwenden, dann best-effort ablegen.
///
/// Dass „sofort" und „abgelegt" zwei Dinge sind, ist der Grund für diese
/// Datei. Der `ThemeBloc` schluckt einen Schreibfehler absichtlich — sonst
/// spränge die Oberfläche auf die alte Größe zurück, während der Anwalt noch
/// auf den Knopf zeigt. Ein verschluckter Fehler ist aber auch die bequemste
/// Stelle, an der eine Umstellung still kaputtgeht: Wer den `emit` hinter den
/// `try` schöbe, bekäme eine Einstellung, die nur manchmal wirkt.
void main() {
  late MerkenderThemeSpeicher speicher;
  late ThemeBloc bloc;

  setUp(() {
    speicher = MerkenderThemeSpeicher();
    bloc = ThemeBloc(speicher);
  });

  tearDown(() => bloc.close());

  test('startet auf der Vorgabestufe', () {
    expect(bloc.state.schriftstufe, Schriftstufe.vorgabe);
  });

  test('eine neue Stufe wird angewendet und abgelegt', () async {
    bloc.add(ChangeSchriftstufeEvent(Schriftstufe.amGroessten));
    final nachher = await bloc.stream.first;

    expect(nachher.schriftstufe, Schriftstufe.amGroessten);
    expect(speicher.gespeichert, hasLength(1));
    expect(speicher.gespeichert.single.schriftstufe, Schriftstufe.amGroessten);
  });

  test('die Stufe laesst Design und Modus unberuehrt', () async {
    bloc.add(ChangeThemeVariantEvent(AppThemeVariant.standard));
    await bloc.stream.first;
    bloc.add(ChangeThemeModeEvent(ThemeMode.dark));
    await bloc.stream.first;

    bloc.add(ChangeSchriftstufeEvent(Schriftstufe.normal));
    final nachher = await bloc.stream.first;

    expect(nachher.schriftstufe, Schriftstufe.normal);
    expect(
      nachher.preferences,
      const ThemePreferences(
        variant: AppThemeVariant.standard,
        mode: ThemeMode.dark,
        schriftstufe: Schriftstufe.normal,
      ),
      reason:
          'Die drei Auswahlen liegen in einem Satz. Ein copyWith, das ein '
          'Nachbarfeld überschreibt, setzt beim Verstellen der Schrift das '
          'Design zurück.',
    );
  });

  test('ein Speicherfehler nimmt die Aenderung nicht zurueck', () async {
    speicher.speichernSchlaegtFehl = true;

    bloc.add(ChangeSchriftstufeEvent(Schriftstufe.normal));
    final nachher = await bloc.stream.first;

    expect(nachher.schriftstufe, Schriftstufe.normal);
    expect(speicher.gespeichert, isEmpty);
    // Der Bloc lebt weiter: Ein durchgereichter Fehler ließe ihn in
    // `addError` laufen und die nächste Auswahl ins Leere greifen.
    bloc.add(ChangeSchriftstufeEvent(Schriftstufe.amGroessten));
    expect((await bloc.stream.first).schriftstufe, Schriftstufe.amGroessten);
  });

  test('der abgelegte Stand kommt beim naechsten Start zurueck', () async {
    speicher.stand = const ThemePreferences(
      variant: AppThemeVariant.kanzlei,
      mode: ThemeMode.light,
      schriftstufe: Schriftstufe.amGroessten,
    );

    bloc.add(LoadThemeEvent());
    final geladen = await bloc.stream.first;

    expect(geladen.schriftstufe, Schriftstufe.amGroessten);
  });
}
