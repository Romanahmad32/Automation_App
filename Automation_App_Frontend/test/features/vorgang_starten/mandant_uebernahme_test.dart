import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/views/vorgang_starten_form_view.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'vorgang_starten_doubles.dart';

/// Ein neu angelegter Mandant muss auf **jedem** Weg in der Karte ankommen.
///
/// Es gibt zwei Wege, beim Starten eines Vorgangs einen Mandanten anzulegen:
/// den Knopf in der Mandanten-Karte und die Aktionsleiste unten („Vorgang
/// speichern" / „Zentralruf-Formular ausfüllen"). Nur der erste räumte danach
/// auf — er meldet `MandantGespeichert`, die View verknüpft den Mandanten.
///
/// Der zweite meldete nichts. Die Karte hielt den Mandanten weiter für *neu*,
/// und der nächste Klick auf „Speichern" legte **denselben Mandanten ein
/// zweites Mal** an. Eine Dublette im Mandantenregister ist Datenschaden, nicht
/// Bedienärger — deshalb zählt dieser Test die Anlagen, statt nur die Anzeige
/// zu prüfen.
void main() {
  late MandantenRegisterDouble register;
  late VorgangStartenBloc bloc;

  /// Der Mandant, den die Karte gerade als verknüpft führt (null = „neuer
  /// Mandant"). Das ist der Wert, an dem die Dublette hängt.
  int? gewaehlterMandant(WidgetTester tester) => tester
      .widget<MandantSection>(find.byType(MandantSection))
      .selectedMandantId;

  /// Baut Doubles, Bloc und Formular und füllt es über die FormGroup — der Test
  /// prüft den Datenpfad nach dem Speichern, nicht das Tippen in die Felder.
  ///
  /// Bloc und Cubit entstehen **hier** und nicht in `setUp`: Was dort gebaut
  /// wird, hängt an der echten Ereignisschleife statt an der Testuhr von
  /// `testWidgets` — der Bloc käme dann über `VorgangStartenLoading` nie hinaus,
  /// egal wie oft der Test pumpt.
  Future<void> zeigeFormular(WidgetTester tester) async {
    register = MandantenRegisterDouble();
    final vorgaenge = VorgangCubit(
      VorgangAblageDouble(),
      VorgangPersistenzFehlerCubit(),
    );
    bloc = VorgangStartenBloc(
      FesterZentralrufPrefill(
        const ZentralrufPrefillResult(
          referenz: '84/26 C03_GG-XY 123',
          filledFields: [],
          skippedFields: [],
        ),
      ),
      OhneKanzleiEinstellungen(),
      MandantAnlegenDouble(register),
      MandantAktualisierenDouble(register),
      vorgaenge,
    );
    getIt.registerSingleton<UseCase<List<Mandant>, NoParams>>(
      MandantenListeDouble(register),
    );
    // Nur die Registrierung wird zurückgenommen. `bloc.close()` wartet auf
    // Mikrotasks der Testuhr — die treibt nach dem Testkörper niemand mehr an,
    // der Lauf bliebe schweigend hängen. Mit dem Testprozess ist der Bloc weg.
    addTearDown(() => getIt.reset());

    // Breit genug, dass die Aktionsleiste nicht überläuft — die Vorgabe von
    // 800x600 reicht diesem Formular nicht. Über `tester.view` statt
    // `setSurfaceSize`: `view.reset` ist synchron und hängt das Aufräumen nicht.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const VorgangStartenFormView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final form = tester
        .widget<ReactiveForm>(find.byType(ReactiveForm))
        .formGroup;
    form.control('auftragsnummer').updateValue('84');
    form.control('kennzeichenGegner').updateValue('GG-XY 123');
    form.control('schadentag').updateValue('01.03.2026');
    form.control('mandantVorname').updateValue('Max');
    form.control('mandantNachname').updateValue('Müller');
    form.control('mandantKennzeichen').updateValue('HG-E 1427');
    await tester.pumpAndSettle();
  }

  /// Drückt „Zentralruf-Formular ausfüllen" und bestätigt die Übersicht, falls
  /// eine aufgeht. Kehrt erst zurück, wenn gespeichert und übernommen ist.
  ///
  /// Das Warten ist kein Zierrat: `showDialog` gibt sein Ergebnis erst frei,
  /// wenn die Ausblende-Animation durch ist. Die Speicherkette startet also erst
  /// nach dem letzten Frame, den ein `pumpAndSettle` sieht — wer direkt danach
  /// misst, misst den Ladezustand und hält die Übernahme fälschlich für kaputt.
  ///
  /// Gewartet wird mit einer festen Zahl `pump`-Frames, nicht mit
  /// `pumpAndSettle`: Solange der Bloc lädt, dreht sich der Ladekringel in der
  /// Aktionsleiste. „Pumpen, bis nichts mehr animiert" käme da nie zur Ruhe und
  /// liefe nach zehn Minuten Testuhr in seinen Timeout — der Lauf hängt dann
  /// minutenlang, statt etwas zu sagen. Auf `bloc.stream` zu horchen wäre die
  /// genauere Abbruchbedingung und ist trotzdem keine: ein Abonnement auf den
  /// Bloc überlebt den Testkörper und blockiert das Aufräumen.
  Future<void> zentralrufAusfuellen(WidgetTester tester) async {
    await tester.tap(find.text('Zentralruf-Formular ausfüllen'));
    await tester.pumpAndSettle();
    // Beim zweiten Durchlauf kommt keine Übersicht mehr — genau das ist der
    // Beweis, dass der Mandant inzwischen verknüpft ist.
    if (tester.any(find.widgetWithText(FilledButton, 'Anlegen'))) {
      await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    }
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      bloc.state,
      isA<VorgangGespeichert>(),
      reason: 'Der Vorgang wurde nicht gespeichert',
    );
  }

  testWidgets('übernimmt den auf dem Zentralruf-Weg angelegten Mandanten in '
      'die Karte', (tester) async {
    await zeigeFormular(tester);
    await zentralrufAusfuellen(tester);

    expect(register.anlagen, 1);
    expect(gewaehlterMandant(tester), register.bestand.single.id);
  });

  testWidgets(
    'legt denselben Mandanten beim zweiten Speichern nicht erneut an',
    (tester) async {
      await zeigeFormular(tester);
      await zentralrufAusfuellen(tester);
      await zentralrufAusfuellen(tester);

      // Ohne die Übernahme stünde hier 2: derselbe Mensch zweimal im Register.
      expect(register.anlagen, 1);
      expect(register.bestand, hasLength(1));
    },
  );

  testWidgets('sperrt den Karten-Knopf, sobald der Mandant verknüpft ist', (
    tester,
  ) async {
    await zeigeFormular(tester);
    expect(find.text('Neuen Mandanten speichern'), findsOneWidget);

    await zentralrufAusfuellen(tester);

    // Nichts mehr anzulegen: der Knopf wechselt auf „aktualisieren" und ist
    // mangels Abweichung nicht drückbar.
    expect(find.text('Neuen Mandanten speichern'), findsNothing);
    final knopf = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Mandantendaten aktualisieren'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(knopf.onPressed, isNull);
  });
}
