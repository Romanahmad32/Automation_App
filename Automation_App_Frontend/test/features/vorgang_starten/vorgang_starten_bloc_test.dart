import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vorgang_starten_doubles.dart';

/// Der Bloc bekommt sein Register **nur** über [anlegen]: Das Aktualisieren
/// leitet sich daraus ab, statt als zweites Argument danebenzustehen. Sonst
/// ließen sich zwei verschiedene Register hineinreichen, und der Test prüfte
/// eine Lage, die es im Betrieb nicht gibt.
VorgangStartenBloc _baue(
  VorgangCubit vorgaenge,
  MandantAnlegenDouble anlegen, {
  UseCase<ZentralrufPrefillResult, ZentralrufRequest>? vorbefuellung,
}) {
  return VorgangStartenBloc(
    vorbefuellung ??
        FesterZentralrufPrefill(
          const ZentralrufPrefillResult(
            referenz: '84/26 C03_GG-XY 123',
            filledFields: [],
            skippedFields: [],
          ),
        ),
    OhneKanzleiEinstellungen(),
    anlegen,
    MandantAktualisierenDouble(anlegen.register),
    vorgaenge,
  );
}

const _verkehrsunfall = VorgangStartenDaten(
  auftragsnummer: 84,
  auftragsjahr: 26,
  abteilung: 'C03',
  rechtsgebiet: RechtsgebietWert.verkehrsrecht,
  referenz: '84/26 C03_GG-XY 123',
  vorname: 'Max',
  nachname: 'Müller',
  kennzeichenGegner: 'GG-XY 123',
  unfallort: 'Am Ulmenrück, Frankfurt',
);

void main() {
  test(
    'legt beim Speichern einen neuen Mandanten an und verknüpft den Vorgang',
    () async {
      final datasource = VorgangAblageDouble();
      final vorgaenge = VorgangCubit(
        datasource,
        VorgangPersistenzFehlerCubit(),
      );
      final createMandant = MandantAnlegenDouble(MandantenRegisterDouble());
      final bloc = _baue(vorgaenge, createMandant);

      bloc.add(
        SpeichereVorgangEvent(
          daten: _verkehrsunfall,
          neuerMandant: _verkehrsunfall.toCreateRequest(),
        ),
      );

      final zustand =
          await bloc.stream.firstWhere((s) => s is VorgangGespeichert)
              as VorgangGespeichert;

      expect(createMandant.letzteAnfrage?.nachname, 'Müller');
      // Der angelegte Mandant muss den Zustand verlassen: sonst weiß die View
      // nichts von ihm und läuft beim nächsten Speichern in den Namenskonflikt.
      expect(zustand.gespeicherterMandant?.id, 7);
      expect(zustand.gespeicherterMandant?.anzeigename, 'Max Müller');
      expect(vorgaenge.state, hasLength(1));
      final vorgang = vorgaenge.state.single;
      expect(vorgang.referenz, '84/26 C03_GG-XY 123');
      expect(vorgang.status, VorgangStatus.angefragt);
      expect(vorgang.mandantId, 7);
      expect(vorgang.mandantName, 'Max Müller');
      expect(vorgang.rechtsgebiet, RechtsgebietWert.verkehrsrecht);
      expect(vorgang.unfallort, 'Am Ulmenrück, Frankfurt');
      expect(datasource.vorgaenge, hasLength(1));

      await bloc.close();
      await vorgaenge.close();
    },
  );

  test('meldet auch den aktualisierten Mandanten im Erfolgszustand', () async {
    final vorgaenge = VorgangCubit(
      VorgangAblageDouble(),
      VorgangPersistenzFehlerCubit(),
    );
    final register = MandantenRegisterDouble();
    // Über `hinterlege`, nicht über `anlegen`: Der Zähler soll bei 0 starten.
    final bestehend = register.hinterlege(
      const CreateMandantRequest(vorname: 'Max', nachname: 'Müller'),
    );
    final bloc = _baue(vorgaenge, MandantAnlegenDouble(register));

    const daten = VorgangStartenDaten(
      auftragsnummer: 84,
      auftragsjahr: 26,
      abteilung: 'C03',
      rechtsgebiet: RechtsgebietWert.verkehrsrecht,
      referenz: '84/26 C03_GG-XY 123',
      vorname: 'Max',
      nachname: 'Müller',
      ort: 'Frankfurt',
      kennzeichenGegner: 'GG-XY 123',
    );

    bloc.add(
      SpeichereVorgangEvent(
        daten: daten,
        aktualisierterMandant: daten.applyTo(bestehend),
        verknuepfteMandantId: bestehend.id,
      ),
    );

    final zustand =
        await bloc.stream.firstWhere((s) => s is VorgangGespeichert)
            as VorgangGespeichert;

    expect(register.anlagen, 0);
    expect(register.aktualisierungen, 1);
    expect(zustand.gespeicherterMandant?.id, bestehend.id);
    expect(zustand.gespeicherterMandant?.ort, 'Frankfurt');
    expect(vorgaenge.state.single.mandantId, bestehend.id);

    await bloc.close();
    await vorgaenge.close();
  });

  /// Der Fehlerpfad, an dem die Reparatur sonst vorbeiläuft: Der Mandant ist
  /// angelegt, erst danach scheitert das Vorbefüllen. Ohne ihn im Fehlerzustand
  /// wüsste die Karte nichts von ihm, und der zweite Versuch käme über den
  /// Namenskonflikt des Backends nicht mehr hinaus.
  test(
    'meldet den Mandanten auch, wenn danach das Vorbefüllen scheitert',
    () async {
      final vorgaenge = VorgangCubit(
        VorgangAblageDouble(),
        VorgangPersistenzFehlerCubit(),
      );
      final register = MandantenRegisterDouble();
      final bloc = _baue(
        vorgaenge,
        MandantAnlegenDouble(register),
        vorbefuellung: ScheiterndeZentralrufVorbefuellung(),
      );

      bloc.add(
        SpeichereVorgangEvent(
          daten: _verkehrsunfall,
          neuerMandant: _verkehrsunfall.toCreateRequest(),
          zentralrufAusfuellen: true,
        ),
      );

      final zustand =
          await bloc.stream.firstWhere((s) => s is VorgangStartenError)
              as VorgangStartenError;

      expect(zustand.gespeicherterMandant?.id, 7);
      expect(register.bestand, hasLength(1));
      // Der Vorgang selbst entsteht nicht — das Vorbefüllen ist Teil dieses Wegs.
      expect(vorgaenge.state, isEmpty);

      await bloc.close();
      await vorgaenge.close();
    },
  );

  /// Was ohne die Verknüpfung passiert: kein zweiter Eintrag, sondern ein
  /// Riegel. Der Test hält fest, wovor die Übernahme schützt.
  test('läuft beim zweiten Anlegen desselben Namens in den Konflikt', () async {
    final vorgaenge = VorgangCubit(
      VorgangAblageDouble(),
      VorgangPersistenzFehlerCubit(),
    );
    final register = MandantenRegisterDouble();
    register.hinterlege(
      const CreateMandantRequest(vorname: 'Max', nachname: 'Müller'),
    );
    final bloc = _baue(vorgaenge, MandantAnlegenDouble(register));

    bloc.add(
      SpeichereVorgangEvent(
        daten: _verkehrsunfall,
        neuerMandant: _verkehrsunfall.toCreateRequest(),
      ),
    );

    final zustand =
        await bloc.stream.firstWhere((s) => s is VorgangStartenError)
            as VorgangStartenError;

    expect(zustand.message, contains('bereits vorhanden'));
    expect(register.bestand, hasLength(1));
    // Kein Mandant angelegt, also auch keiner zu verknüpfen.
    expect(zustand.gespeicherterMandant, isNull);
    // Und der Vorgang bleibt liegen: Das ist die Sackgasse.
    expect(vorgaenge.state, isEmpty);

    await bloc.close();
    await vorgaenge.close();
  });

  test(
    'SpeichereMandantEvent legt nur den Mandanten an (ohne Vorgang)',
    () async {
      final datasource = VorgangAblageDouble();
      final vorgaenge = VorgangCubit(
        datasource,
        VorgangPersistenzFehlerCubit(),
      );
      final bloc = _baue(
        vorgaenge,
        MandantAnlegenDouble(MandantenRegisterDouble()),
      );

      bloc.add(
        const SpeichereMandantEvent(
          neuerMandant: CreateMandantRequest(
            vorname: 'Max',
            nachname: 'Müller',
          ),
        ),
      );

      final state =
          await bloc.stream.firstWhere((s) => s is MandantGespeichert)
              as MandantGespeichert;

      expect(state.warNeu, isTrue);
      expect(state.mandant.id, 7);
      expect(state.mandant.anzeigename, 'Max Müller');
      // Es wird kein Vorgang angelegt.
      expect(vorgaenge.state, isEmpty);
      expect(datasource.vorgaenge, isEmpty);

      await bloc.close();
      await vorgaenge.close();
    },
  );

  test(
    'speichert ohne Mandant nur den Vorgang (Nicht-Verkehrsrecht)',
    () async {
      final datasource = VorgangAblageDouble();
      final vorgaenge = VorgangCubit(
        datasource,
        VorgangPersistenzFehlerCubit(),
      );
      final createMandant = MandantAnlegenDouble(MandantenRegisterDouble());
      final bloc = _baue(vorgaenge, createMandant);

      const daten = VorgangStartenDaten(
        auftragsnummer: 90,
        auftragsjahr: 26,
        abteilung: 'C03',
        rechtsgebiet: 'Arbeitsrecht',
        referenz: '90/26 C03',
      );

      bloc.add(const SpeichereVorgangEvent(daten: daten));
      final zustand =
          await bloc.stream.firstWhere((s) => s is VorgangGespeichert)
              as VorgangGespeichert;

      expect(createMandant.letzteAnfrage, isNull);
      // Ohne Mandantenarbeit bleibt das Feld leer — die View hat dann nichts
      // nachzuziehen.
      expect(zustand.gespeicherterMandant, isNull);
      final vorgang = vorgaenge.state.single;
      expect(vorgang.referenz, '90/26 C03');
      expect(vorgang.mandantId, isNull);
      expect(vorgang.rechtsgebiet, 'Arbeitsrecht');
      // Unfallfelder bleiben außerhalb von Verkehrsrecht leer.
      expect(vorgang.unfallort, isNull);

      await bloc.close();
      await vorgaenge.close();
    },
  );
}
