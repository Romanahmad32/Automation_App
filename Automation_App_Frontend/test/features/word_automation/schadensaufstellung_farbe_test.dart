import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schadensaufstellung_schritt.dart';

/// Lässt sich von aussen steuern, wann `LoadKanzleiSettingsEvent` beantwortet
/// wird — genau die Lücke, die den Fehler auslöst: `word_automation_page.dart`
/// legt den `KanzleiSettingsBloc` bei jedem Öffnen des Tabs frisch an und
/// stösst das Laden dort an; bis die Antwort da ist, steht der Bloc auf
/// `KanzleiSettingsLoading`.
class _VerzoegerteSettings implements UseCase<KanzleiSettings, NoParams> {
  final Completer<KanzleiSettings> _antwort = Completer();

  void liefere(KanzleiSettings settings) => _antwort.complete(settings);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(await _antwort.future);
}

class _NieGespeicherteSettings
    implements UseCase<KanzleiSettings, KanzleiSettings> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) =>
      throw UnimplementedError();
}

/// §4.4/Einstellungen „Schadensaufstellung": Die konfigurierte
/// Titelzeilen-Farbe muss stehen, sobald der Schritt eine bereits erfasste
/// Aufstellung zeigt — nicht erst nach der ersten Eingabe (Bug: Der Anwalt
/// sah die Standardfarbe, bis er einen Betrag antippte).
void main() {
  const konfigurierteFarbe = 'ABCDEF';

  Vorgang vorgangMitAufstellung() => Vorgang(
    referenz: '84/26 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 6, 12),
    schadensaufstellung: const DamageListing(
      items: [DamageItem(description: 'Reparaturkosten', amount: 500)],
      // Kein headerColorHex: So kommt eine gespeicherte Aufstellung aus dem
      // Bestand tatsächlich an — die Farbe wird erst beim Anzeigen ergänzt.
    ),
  );

  Color? kopfzeilenFarbe(WidgetTester tester) {
    final table = tester.widget<Table>(find.byType(Table));
    final decoration = table.children.first.decoration as BoxDecoration?;
    return decoration?.color;
  }

  testWidgets(
    'übernimmt die konfigurierte Farbe, sobald die Einstellungen laden — '
    'auch ohne Eingabe',
    (tester) async {
      final settings = _VerzoegerteSettings();
      final kanzleiSettingsBloc = KanzleiSettingsBloc(
        settings,
        _NieGespeicherteSettings(),
      )..add(const LoadKanzleiSettingsEvent());

      final schritt = SchadensaufstellungSchritt();
      addTearDown(schritt.schliesse);
      addTearDown(kanzleiSettingsBloc.close);

      await schritt.zeige(tester, kanzleiSettingsBloc: kanzleiSettingsBloc);

      // Die Aufstellung des Vorgangs übernehmen — wie beim Betreten des
      // Schritts zu einem bereits bearbeiteten Vorgang.
      final vorgang = vorgangMitAufstellung();
      await schritt.umgebung.wizard.selectVorgang(vorgang);
      schritt.umgebung.wizard.setMitAuflistung(true);
      schritt.umgebung.wizard.goToStep(WizardStep.schadensaufstellung);
      // Wartet die Entprellung des RvgCalculationBloc ab (350 ms) — sonst
      // meldet der Test noch einen wartenden Timer als "still pending".
      await beruhige(tester);

      // Die Einstellungen laden noch: Der Schritt zeigt bereits die
      // Aufstellung, aber noch mit der Standardfarbe — das ist der Fehler,
      // solange die Reparatur fehlt.
      expect(
        kopfzeilenFarbe(tester),
        equals(const Color(0xFFD9D9D9)),
        reason: 'Vor dem Laden der Einstellungen steht die Standardfarbe.',
      );

      // Die Einstellungen treffen ein.
      settings.liefere(
        const KanzleiSettings(tabellenkopfFarbeHex: konfigurierteFarbe),
      );
      await beruhige(tester);

      expect(
        kopfzeilenFarbe(tester),
        equals(const Color(0xFFABCDEF)),
        reason:
            'Nach dem Laden der Einstellungen muss die konfigurierte Farbe '
            'stehen — ohne dass der Anwalt etwas eingegeben hat.',
      );
    },
  );
}
