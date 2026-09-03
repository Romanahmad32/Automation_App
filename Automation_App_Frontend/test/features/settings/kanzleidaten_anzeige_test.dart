import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/views/app_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'package:automation_app/core/di/injection.dart';

import '../sachgebiete/sachgebiet_test_katalog.dart';
import 'kanzlei_settings_doubles.dart';

/// Die gespeicherten Kanzleidaten müssen im Formular stehen, **wann immer** es
/// aufgeht — auch dann, wenn der Bloc schon geladen war.
///
/// Dritte Stelle desselben Musters (Signatur, Postfach-Zugang, hier). Ein
/// `BlocConsumer.listener` hört nur Übergänge; den Zustand, auf dem der Bloc
/// beim Mounten steht, sieht er nicht. Ob das auffällt, hängt allein daran, ob
/// der Bloc mit der Seite neu entsteht — und das sieht man dem Widget nicht an.
/// Genau deshalb steht der Fall hier als Test und nicht als Kommentar.
///
/// Hier ist der Weg heute unauffällig (das Formular liegt im ersten Reiter und
/// ist gemountet, bevor geladen wird). Er kippt, sobald die Reiter umsortiert
/// werden, der Bloc weiter oben entsteht oder das Formular anderswo eingebaut
/// wird — lauter Änderungen, die niemand als riskant liest.
///
/// Getragen wird beides von `StandNachziehen` (`core/general_widgets/`).
void main() {
  const gespeichert = KanzleiSettings(
    name: 'Kanzlei Ahmad',
    ort: 'Bad Homburg',
    emailAdresse: 'kanzlei@example.de',
    abteilung: 'VU',
    vorlagenOrdner: r'C:\Kanzlei\Vorlagen',
    sicherungsAblageOrdner: r'C:\OneDrive\Kanzlei-Sicherungen',
  );

  /// Der Wert, der beim Speichern gelesen wird — nicht irgendein Text auf dem
  /// Schirm.
  Object? imFeld(WidgetTester tester, String name) => tester
      .widget<ReactiveForm>(find.byType(ReactiveForm).first)
      .formGroup
      .control(name)
      .value;

  Future<void> zeige(WidgetTester tester, {required bool schonGeladen}) async {
    // Die Abteilungs-Auswahl im Formular zieht den Sachgebietskatalog.
    registriereSachgebietKatalog();
    addTearDown(() => getIt.reset());
    final bloc = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      DurchreichendesSpeichern(),
    );
    addTearDown(bloc.close);

    if (schonGeladen) {
      final fertig = bloc.stream.firstWhere((s) => s is KanzleiSettingsLoaded);
      bloc.add(const LoadKanzleiSettingsEvent());
      await fertig;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(value: bloc, child: const AppSettingsView()),
        ),
      ),
    );

    if (!schonGeladen) bloc.add(const LoadKanzleiSettingsEvent());
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt die gespeicherten Kanzleidaten beim ersten Öffnen', (
    tester,
  ) async {
    await zeige(tester, schonGeladen: false);

    expect(imFeld(tester, 'name'), gespeichert.name);
    expect(imFeld(tester, 'ort'), gespeichert.ort);
    expect(imFeld(tester, 'vorlagenOrdner'), gespeichert.vorlagenOrdner);
    expect(
      imFeld(tester, 'sicherungsAblageOrdner'),
      gespeichert.sicherungsAblageOrdner,
    );
  });

  testWidgets('zeigt sie auch, wenn der Bloc schon geladen war', (
    tester,
  ) async {
    await zeige(tester, schonGeladen: true);

    expect(
      imFeld(tester, 'name'),
      gespeichert.name,
      reason:
          'Das Formular steht auf seinen Vorgabewerten statt auf den '
          'geladenen Kanzleidaten — Speichern schriebe sie darüber.',
    );
    expect(imFeld(tester, 'abteilung'), gespeichert.abteilung);
  });
}
