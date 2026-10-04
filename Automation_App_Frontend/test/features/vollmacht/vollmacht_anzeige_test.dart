import 'dart:convert';

import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_formular.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_stand_zeile.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_vorlage_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Was der Anwalt von der Vollmacht sieht (§4.11): die Standzeile in der
/// Kachel, der Stand der Vorlagen und der Dialog ohne Mandant.
void main() {
  Vorgang vorgang({DateTime? gedruckt}) => Vorgang(
    referenz: '12/26 C05_GG-XY 1',
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: 'Strafrecht',
    abteilung: 'C05',
    vollmachtGedrucktAm: gedruckt,
  );

  Future<void> zeige(WidgetTester tester, Widget kind) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: kind)),
    ),
  );

  group('Standzeile in der Kachel', () {
    testWidgets('nennt das Druckdatum und bietet die Rücknahme an', (
      tester,
    ) async {
      await zeige(
        tester,
        VollmachtStandZeile(vorgang: vorgang(gedruckt: DateTime(2026, 9, 13))),
      );

      expect(find.text('Vollmacht gedruckt am 13.09.2026'), findsOneWidget);
      expect(find.text('Vermerk zurücknehmen'), findsOneWidget);
    });

    testWidgets('sagt, dass noch nicht gedruckt ist', (tester) async {
      await zeige(tester, VollmachtStandZeile(vorgang: vorgang()));

      expect(find.text('Vollmacht noch nicht gedruckt'), findsOneWidget);
      expect(find.text('als gedruckt vermerken'), findsOneWidget);
    });
  });

  test('der Vorlagenstand sagt, was fehlt', () {
    const fehlt = VollmachtVorlage(
      art: VollmachtArt.bussgeldsachen,
      dateiname: 'Vollmacht Bussgeldsachen.docx',
      vorhanden: false,
    );
    final da = VollmachtVorlage(
      art: VollmachtArt.strafsache,
      dateiname: 'Vollmacht Strafsache.docx',
      vorhanden: true,
      geaendertAm: DateTime(2026, 9, 10),
    );

    expect(VollmachtVorlageZeile.satz(fehlt), contains('fehlt'));
    expect(
      VollmachtVorlageZeile.satz(da),
      'Strafsache: „Vollmacht Strafsache.docx“ vorhanden, geändert am 10.09.2026',
    );
  });

  test('ein unbekannter Status des Dienstes ist nie ein Erfolg', () {
    final ergebnis = VollmachtErgebnis.fromJson({'status': 'irgendwas'});
    expect(ergebnis.status, VollmachtErgebnisStatus.fehler);
  });

  test('die Seite der Vorschau kommt als Base64 und wird zu Bytes', () {
    // So schreibt System.Text.Json ein byte[] (VollmachtVorschauDto.Pdf).
    final vorschau = VollmachtVorschau.fromJson({
      'status': 'erstellt',
      'pdf': base64Encode([37, 80, 68, 70]),
      'warnungen': ['Tatdatum'],
    });

    expect(vorschau.status, VollmachtVorschauStatus.erstellt);
    expect(vorschau.pdf, [37, 80, 68, 70]);
    expect(vorschau.warnungen, ['Tatdatum']);
    expect(
      VollmachtVorschau.fromJson({'status': 'neu'}).status,
      VollmachtVorschauStatus.fehler,
    );
  });

  test('ein unbekannter Druckerzustand ist nie „bereit"', () {
    final drucker = VollmachtDrucker.fromJson({'name': 'X', 'zustand': 'neu'});

    expect(drucker.zustand, VollmachtDruckerZustand.unbekannt);
    expect(drucker.kannDrucken, isTrue);
    expect(
      VollmachtDrucker.fromJson({'zustand': 'keinDrucker'}).kannDrucken,
      isFalse,
    );
  });

  testWidgets('der Dialog ohne Mandant sagt, warum die Felder leer sind', (
    tester,
  ) async {
    // Aufbau im testWidgets, nie in setUp: Sonst läuft der Cubit außerhalb
    // der Fake-Zone, und der Test wartet ewig.
    late VollmachtCubit cubit;
    await tester.runAsync(() async {
      final aufbau = await baueVollmachtCubit(
        VollmachtRepositoryDouble(),
        VollmachtVorgaengeDouble(),
      );
      cubit = aufbau.cubit;
      await cubit.starte(vorgang(), const []);
    });
    addTearDown(cubit.close);

    await zeige(
      tester,
      BlocProvider.value(
        value: cubit,
        child: VollmachtFormular(stand: cubit.state),
      ),
    );

    expect(find.textContaining('kein Mandant zugeordnet'), findsOneWidget);
    expect(find.text('Strafsache'), findsOneWidget);
    expect(find.textContaining('Bankverbindung'), findsNothing);
  });
}
