import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/views/vorgang_starten_form_view.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_section.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sachgebiete/sachgebiet_test_katalog.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'vorgang_starten_doubles.dart';

/// Ein gespeicherter Mandant muss auf **jedem** Weg in der Karte ankommen.
///
/// Es gibt zwei Wege, beim Starten eines Vorgangs einen Mandanten anzulegen:
/// den Knopf in der Mandanten-Karte und die Aktionsleiste unten („Vorgang
/// speichern" / „Zentralruf-Formular ausfüllen"). Nur der erste räumte danach
/// auf — er meldet `MandantGespeichert`, die View verknüpft den Mandanten.
///
/// Der zweite meldete nichts, und die Karte hielt den Mandanten weiter für
/// *neu*. Der nächste Klick auf „Speichern" versuchte ihn deshalb ein zweites
/// Mal anzulegen — und lief in den Riegel des Backends: `EnsureNameUniqueAsync`
/// lässt denselben Namen kein zweites Mal zu, der Controller antwortet 409.
/// Es entstand also keine Dublette, sondern eine **Sackgasse**: Der Vorgang
/// ließ sich ab da überhaupt nicht mehr speichern, bis jemand die Seite neu
/// lud. Deshalb bildet [MandantenRegisterDouble] den Konflikt nach — ohne ihn
/// prüften diese Tests eine Welt, in der das Backend alles hinnimmt.
void main() {
  late MandantenRegisterDouble register;
  late VorgangStartenBloc bloc;

  /// Jeder Zustand, den der Bloc gemeldet hat — über einen `BlocListener` im
  /// Baum, nicht über `bloc.stream`: Ein von Hand geöffnetes Abonnement
  /// überlebt den Testkörper und blockiert das Aufräumen; dieses hier stirbt
  /// mit dem Widget.
  late List<VorgangStartenState> protokoll;

  /// Der Mandant, den die Karte gerade als verknüpft führt (null = „neuer
  /// Mandant"). Das ist der Wert, an dem die Sackgasse hängt.
  int? gewaehlterMandant(WidgetTester tester) => tester
      .widget<MandantSection>(find.byType(MandantSection))
      .selectedMandantId;

  FormGroup formular(WidgetTester tester) =>
      tester.widget<ReactiveForm>(find.byType(ReactiveForm)).formGroup;

  /// Wie oft der Bloc einen Speicherlauf abgeschlossen hat — mit Erfolg oder
  /// mit Fehler. Daran hängt das Warten unten.
  int laeufe() => protokoll
      .where((s) => s is VorgangGespeichert || s is VorgangStartenError)
      .length;

  /// Baut Doubles, Bloc und Formular und füllt es über die FormGroup — der Test
  /// prüft den Datenpfad nach dem Speichern, nicht das Tippen in die Felder.
  ///
  /// Bloc und Cubit entstehen **hier** und nicht in `setUp`: Was dort gebaut
  /// wird, hängt an der echten Ereignisschleife statt an der Testuhr von
  /// `testWidgets` — der Bloc käme dann über `VorgangStartenLoading` nie hinaus,
  /// egal wie oft der Test pumpt.
  Future<void> zeigeFormular(
    WidgetTester tester, {
    UseCase<ZentralrufPrefillResult, ZentralrufRequest>? vorbefuellung,
    String mandantKennzeichen = 'HG-E 1427',
  }) async {
    register = MandantenRegisterDouble();
    protokoll = [];
    final vorgaenge = VorgangCubit(
      VorgangAblageDouble(),
      VorgangPersistenzFehlerCubit(),
    );
    bloc = VorgangStartenBloc(
      vorbefuellung ??
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
    // Die Karte fragt den Bestand nach den Vorgängen am verknüpften Mandanten,
    // um vor einer Umbenennung mit einer Zahl zu warnen. Ohne Registrierung
    // fiele das Formular schon beim Aufbauen um.
    getIt.registerSingleton<VorgangCubit>(vorgaenge);
    // Die Auftrag-Karte zieht ihre Auswahlen aus dem Sachgebietskatalog.
    registriereSachgebietKatalog();
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
            child: BlocListener<VorgangStartenBloc, VorgangStartenState>(
              listener: (_, state) => protokoll.add(state),
              child: const VorgangStartenFormView(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final form = formular(tester);
    form.control('auftragsnummer').updateValue('84');
    form.control('kennzeichenGegner').updateValue('GG-XY 123');
    form.control('schadentag').updateValue('01.03.2026');
    form.control('mandantVorname').updateValue('Max');
    form.control('mandantNachname').updateValue('Müller');
    form.control('mandantKennzeichen').updateValue(mandantKennzeichen);
    await tester.pumpAndSettle();
  }

  /// Drückt „Zentralruf-Formular ausfüllen", bestätigt die Übersicht, falls
  /// eine aufgeht, und kehrt zurück, sobald der Bloc den Lauf abgeschlossen hat.
  ///
  /// Kein `pumpAndSettle`: Solange der Bloc lädt, dreht sich der Ladekringel in
  /// der Aktionsleiste. „Pumpen, bis nichts mehr animiert" käme da nie zur Ruhe
  /// und liefe nach zehn Minuten Testuhr in seinen Timeout — der Lauf hängt
  /// dann minutenlang, statt etwas zu sagen. Gewartet wird deshalb auf das
  /// Protokoll; die Framezahl ist nur die Obergrenze.
  ///
  /// Das Warten selbst ist kein Zierrat: `showDialog` gibt sein Ergebnis erst
  /// frei, wenn die Ausblende-Animation durch ist. Die Speicherkette startet
  /// also erst nach dem letzten Frame, den ein `pumpAndSettle` sähe.
  Future<void> zentralrufAusfuellen(
    WidgetTester tester, {
    String bestaetigen = 'Anlegen',
  }) async {
    final vorher = laeufe();
    await tester.tap(find.text('Zentralruf-Formular ausfüllen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Kommt keine Übersicht, ist am Mandanten nichts zu tun — genau das ist der
    // Beweis, dass er inzwischen verknüpft ist.
    if (tester.any(find.widgetWithText(FilledButton, bestaetigen))) {
      await tester.tap(find.widgetWithText(FilledButton, bestaetigen));
    }
    for (var frame = 0; laeufe() == vorher && frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      laeufe(),
      vorher + 1,
      reason: 'Der Speicherlauf ist nicht zum Abschluss gekommen',
    );
  }

  testWidgets('übernimmt den auf dem Zentralruf-Weg angelegten Mandanten in '
      'die Karte', (tester) async {
    await zeigeFormular(tester);
    await zentralrufAusfuellen(tester);

    expect(register.anlagen, 1);
    expect(gewaehlterMandant(tester), register.bestand.single.id);
  });

  testWidgets('versucht beim zweiten Speichern keine zweite Anlage', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await zentralrufAusfuellen(tester);
    await zentralrufAusfuellen(tester);

    // Ohne die Übernahme stünde hier 2 — und der zweite Versuch käme als
    // Namenskonflikt zurück, statt den Vorgang zu speichern.
    expect(register.anlagen, 1);
    expect(register.bestand, hasLength(1));
    expect(protokoll.whereType<VorgangStartenError>(), isEmpty);
  });

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

  /// Das Kennzeichen wird im Register verglichen — gegen die Zentralruf-Antwort
  /// und gegen das Feld im Anspruchsschreiben. Ein eingefügter Rohwert kommt
  /// hier an, ohne dass das Feld je verlassen wurde: `leseVorgangDaten` zieht
  /// ihn deshalb ein zweites Mal gerade, bevor er in die Anlage-Anfrage geht.
  testWidgets('legt ein getipptes Kennzeichen in der Konvention an', (
    tester,
  ) async {
    await zeigeFormular(tester, mandantKennzeichen: 'hge1427');
    await zentralrufAusfuellen(tester);

    expect(register.bestand.single.kennzeichen, ['HG-E 1427']);
  });

  /// Der Weg, auf dem die Reparatur sonst vorbeiläuft: Der Mandant ist
  /// angelegt, danach scheitert das Vorbefüllen. Er liegt trotzdem im Register
  /// und muss verknüpft werden — sonst ist der zweite Anlauf die Sackgasse.
  testWidgets('verknüpft den Mandanten auch, wenn das Vorbefüllen scheitert', (
    tester,
  ) async {
    await zeigeFormular(
      tester,
      vorbefuellung: ScheiterndeZentralrufVorbefuellung(),
    );
    await zentralrufAusfuellen(tester);

    expect(protokoll.whereType<VorgangStartenError>(), hasLength(1));
    expect(register.anlagen, 1);
    expect(gewaehlterMandant(tester), register.bestand.single.id);

    // Und der zweite Anlauf legt nicht noch einmal an.
    await zentralrufAusfuellen(tester);
    expect(register.anlagen, 1);
  });

  testWidgets('aktualisiert den verknüpften Mandanten, statt neu anzulegen', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await zentralrufAusfuellen(tester);

    formular(tester).control('mandantOrt').updateValue('Frankfurt');
    await tester.pumpAndSettle();
    await zentralrufAusfuellen(tester, bestaetigen: 'Aktualisieren');

    expect(register.anlagen, 1);
    expect(register.aktualisierungen, 1);
    expect(register.bestand, hasLength(1));
    expect(register.bestand.single.ort, 'Frankfurt');
  });

  /// §1.3 — die App „überschreibt nichts stillschweigend". Auf dem
  /// Zentralruf-Weg liegen zwischen Klick und Rückkehr bis zu drei Minuten, in
  /// denen nur die Knöpfe gesperrt sind, die Felder aber bedienbar bleiben.
  testWidgets(
    'überschreibt nicht, was während des Vorbefüllens getippt wurde',
    (tester) async {
      final angehalten = AngehalteneZentralrufVorbefuellung(
        const ZentralrufPrefillResult(
          referenz: '84/26 C03_GG-XY 123',
          filledFields: [],
          skippedFields: [],
        ),
      );
      await zeigeFormular(tester, vorbefuellung: angehalten);

      await tester.tap(find.text('Zentralruf-Formular ausfüllen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
      for (var frame = 0; !angehalten.laeuft && frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(angehalten.laeuft, isTrue, reason: 'Der Bloc wartet nicht');

      // Der Anwalt tippt weiter, während der Browser offen steht.
      formular(tester).control('mandantEmail').updateValue('neu@kanzlei.de');
      await tester.pump();

      angehalten.gib();
      for (var frame = 0; laeufe() == 0 && frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(laeufe(), 1);
      expect(gewaehlterMandant(tester), register.bestand.single.id);
      expect(formular(tester).control('mandantEmail').value, 'neu@kanzlei.de');
    },
  );
}
