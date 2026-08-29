import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vorgang_starten_doubles.dart';

VorgangStartenBloc _baue(
  VorgangCubit vorgaenge,
  MandantenRegisterDouble register,
  MandantAnlegenDouble anlegen,
) {
  return VorgangStartenBloc(
    FesterZentralrufPrefill(
      const ZentralrufPrefillResult(
        referenz: '84/26 C03_GG-XY 123',
        filledFields: [],
        skippedFields: [],
      ),
    ),
    OhneKanzleiEinstellungen(),
    anlegen,
    MandantAktualisierenDouble(register),
    vorgaenge,
  );
}

void main() {
  test(
    'legt beim Speichern einen neuen Mandanten an und verknüpft den Vorgang',
    () async {
      final datasource = VorgangAblageDouble();
      final vorgaenge = VorgangCubit(
        datasource,
        VorgangPersistenzFehlerCubit(),
      );
      final register = MandantenRegisterDouble();
      final createMandant = MandantAnlegenDouble(register);
      final bloc = _baue(vorgaenge, register, createMandant);

      const daten = VorgangStartenDaten(
        auftragsnummer: 84,
        auftragsjahr: 26,
        abteilung: 'C03',
        rechtsgebiet: Rechtsgebiet.verkehrsrecht,
        referenz: '84/26 C03_GG-XY 123',
        vorname: 'Max',
        nachname: 'Müller',
        kennzeichenGegner: 'GG-XY 123',
        unfallort: 'Am Ulmenrück, Frankfurt',
      );

      bloc.add(
        SpeichereVorgangEvent(
          daten: daten,
          neuerMandant: daten.toCreateRequest(),
        ),
      );

      final zustand =
          await bloc.stream.firstWhere((s) => s is VorgangGespeichert)
              as VorgangGespeichert;

      expect(createMandant.letzteAnfrage?.nachname, 'Müller');
      // Der angelegte Mandant muss den Zustand verlassen: sonst weiß die View
      // nichts von ihm und legt ihn beim nächsten Speichern erneut an.
      expect(zustand.gespeicherterMandant?.id, 7);
      expect(zustand.gespeicherterMandant?.anzeigename, 'Max Müller');
      expect(vorgaenge.state, hasLength(1));
      final vorgang = vorgaenge.state.single;
      expect(vorgang.referenz, '84/26 C03_GG-XY 123');
      expect(vorgang.status, VorgangStatus.angefragt);
      expect(vorgang.mandantId, 7);
      expect(vorgang.mandantName, 'Max Müller');
      expect(vorgang.rechtsgebiet, Rechtsgebiet.verkehrsrecht);
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
    final bestehend = register.anlegen(
      const CreateMandantRequest(vorname: 'Max', nachname: 'Müller'),
    );
    final bloc = _baue(vorgaenge, register, MandantAnlegenDouble(register));

    const daten = VorgangStartenDaten(
      auftragsnummer: 84,
      auftragsjahr: 26,
      abteilung: 'C03',
      rechtsgebiet: Rechtsgebiet.verkehrsrecht,
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

    expect(register.aktualisierungen, 1);
    expect(zustand.gespeicherterMandant?.id, bestehend.id);
    expect(zustand.gespeicherterMandant?.ort, 'Frankfurt');
    expect(vorgaenge.state.single.mandantId, bestehend.id);

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
      final register = MandantenRegisterDouble();
      final bloc = _baue(vorgaenge, register, MandantAnlegenDouble(register));

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
      final register = MandantenRegisterDouble();
      final createMandant = MandantAnlegenDouble(register);
      final bloc = _baue(vorgaenge, register, createMandant);

      const daten = VorgangStartenDaten(
        auftragsnummer: 90,
        auftragsjahr: 26,
        abteilung: 'C03',
        rechtsgebiet: Rechtsgebiet.arbeitsrecht,
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
      expect(vorgang.rechtsgebiet, Rechtsgebiet.arbeitsrecht);
      // Unfallfelder bleiben außerhalb von Verkehrsrecht leer.
      expect(vorgang.unfallort, isNull);

      await bloc.close();
      await vorgaenge.close();
    },
  );
}
