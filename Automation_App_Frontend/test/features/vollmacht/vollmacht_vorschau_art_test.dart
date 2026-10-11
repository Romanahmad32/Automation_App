import 'dart:async';
import 'dart:typed_data';

import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Die Vorschau folgt der Art (§4.11, #174): Eine andere Art ist ein anderes
/// Formular, nicht nur ein veralteter Feldwert. Weil jede Umwandlung den
/// Word-Thread belegt, auf dem auch gedruckt wird, läuft nie mehr als eine —
/// und keine für eine Art, die schon wieder abgewählt ist.
void main() {
  const referenz = '12/26 C05_GG-XY 1';
  late VollmachtRepositoryDouble dienst;
  late VollmachtVorgaengeDouble vorgaenge;

  final vorgang = Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: 'Strafrecht',
    abteilung: 'C05',
  );

  setUp(() {
    dienst = VollmachtRepositoryDouble()
      ..vorschau = VollmachtVorschau(
        status: VollmachtVorschauStatus.erstellt,
        pdf: Uint8List.fromList([37, 80, 68, 70]),
      );
    vorgaenge = VollmachtVorgaengeDouble()..bestand[referenz] = vorgang;
  });

  /// Lässt die Aufträge laufen, die ohne `await` angestoßen wurden.
  Future<void> leeren() => Future<void>.delayed(Duration.zero);

  test('ein Wechsel der Art stößt die Vorschau selbst an', () async {
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
    await aufbau.cubit.starte(vorgang, const []);
    await aufbau.cubit.erstelleVorschau();

    aufbau.cubit.waehleArt(VollmachtArt.unfallsachen);
    await leeren();

    expect(dienst.vorschauAuftraege.map((a) => a.art), [
      VollmachtArt.strafsache,
      VollmachtArt.unfallsachen,
    ]);
    expect(aufbau.cubit.state.vorschauVeraltet, isFalse);
  });

  test('dieselbe Art noch einmal gewählt bestellt nichts', () async {
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
    await aufbau.cubit.starte(vorgang, const []);
    await aufbau.cubit.erstelleVorschau();

    aufbau.cubit.waehleArt(VollmachtArt.strafsache);
    await leeren();

    expect(dienst.vorschauAuftraege, hasLength(1));
  });

  test('zweimal umgeschaltet, während eine läuft: genau eine weitere, für die zuletzt gewählte Art', () async {
    final haengt = dienst.vorschauHaengt = Completer<void>();
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
    await aufbau.cubit.starte(vorgang, const []);

    final erste = aufbau.cubit.erstelleVorschau();
    aufbau.cubit.waehleArt(VollmachtArt.unfallsachen);
    aufbau.cubit.waehleArt(VollmachtArt.bussgeldsachen);
    await leeren();
    expect(
      dienst.vorschauAuftraege,
      hasLength(1),
      reason: 'Solange eine läuft, beginnt keine zweite.',
    );

    haengt.complete();
    await erste;

    expect(dienst.vorschauAuftraege.map((a) => a.art), [
      VollmachtArt.strafsache,
      VollmachtArt.bussgeldsachen,
    ]);
    expect(dienst.vorschauenHoechstensGleichzeitig, 1);
    final stand = aufbau.cubit.state;
    expect(stand.vorschauLaedt, isFalse);
    expect(stand.vorschauFuer?.art, VollmachtArt.bussgeldsachen);
    expect(stand.vorschauVeraltet, isFalse);
  });

  test(
    'zurück zur Art der laufenden Vorschau: keine weitere Umwandlung',
    () async {
      final haengt = dienst.vorschauHaengt = Completer<void>();
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang, const []);

      final erste = aufbau.cubit.erstelleVorschau();
      aufbau.cubit.waehleArt(VollmachtArt.unfallsachen);
      aufbau.cubit.waehleArt(VollmachtArt.strafsache);
      haengt.complete();
      await erste;

      expect(dienst.vorschauAuftraege, hasLength(1));
      expect(aufbau.cubit.state.vorschauVeraltet, isFalse);
    },
  );

  test(
    'eine Feldeingabe bestellt keine Vorschau, sie macht sie veraltet',
    () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang, const []);
      await aufbau.cubit.erstelleVorschau();

      aufbau.cubit.aendereKopfdaten(
        aufbau.cubit.state.kopfdaten.copyWith(ort: 'Musterstadt'),
      );
      await leeren();

      expect(dienst.vorschauAuftraege, hasLength(1));
      expect(aufbau.cubit.state.vorschauVeraltet, isTrue);
    },
  );

  test(
    'fehlt die Vorlage der neuen Art, wird keine Vorschau bestellt',
    () async {
      dienst.vorlagen = VollmachtRepositoryDouble.standMit({
        VollmachtArt.strafsache,
      });
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang, const []);
      await aufbau.cubit.erstelleVorschau();

      aufbau.cubit.waehleArt(VollmachtArt.bussgeldsachen);
      await leeren();

      expect(dienst.vorschauAuftraege, hasLength(1));
    },
  );
}
