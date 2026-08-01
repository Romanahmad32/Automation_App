import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePrefill
    implements UseCase<ZentralrufPrefillResult, ZentralrufRequest> {
  final ZentralrufPrefillResult result;
  _FakePrefill(this.result);

  @override
  Future<Either<Failure, ZentralrufPrefillResult>> call(
    ZentralrufRequest params,
  ) async => Right(result);
}

class _FakeGetSettings implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Left(LocalFailure(message: 'keine Einstellungen'));
}

/// Legt einen Mandanten mit fester id an und merkt sich die Anfrage.
class _FakeCreateMandant implements UseCase<Mandant, CreateMandantRequest> {
  CreateMandantRequest? letzteAnfrage;

  @override
  Future<Either<Failure, Mandant>> call(CreateMandantRequest params) async {
    letzteAnfrage = params;
    return Right(
      Mandant(
        id: 7,
        vorname: params.vorname,
        nachname: params.nachname,
        kennzeichen: params.kennzeichen,
        erstelltAm: DateTime(2026),
      ),
    );
  }
}

class _FakeUpdateMandant implements UseCase<Mandant, Mandant> {
  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async => Right(params);
}

class _FakeVorgaengeDatasource implements VorgangRepository {
  List<Vorgang> vorgaenge = const [];

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;

  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async {
    vorgaenge = [
      ...vorgaenge.where(
        (v) => !Vorgang.gleicheReferenz(v.referenz, vorgang.referenz),
      ),
      vorgang,
    ];
    return vorgang;
  }

  @override
  Future<void> deleteVorgang(String referenz) async {
    vorgaenge = vorgaenge
        .where((v) => !Vorgang.gleicheReferenz(v.referenz, referenz))
        .toList();
  }

  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async => null;

  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async => null;
}

VorgangStartenBloc _baue(
  VorgangCubit vorgaenge,
  _FakeCreateMandant createMandant,
) {
  return VorgangStartenBloc(
    _FakePrefill(
      const ZentralrufPrefillResult(
        referenz: '84/26 C03_GG-XY 123',
        filledFields: [],
        skippedFields: [],
      ),
    ),
    _FakeGetSettings(),
    createMandant,
    _FakeUpdateMandant(),
    vorgaenge,
  );
}

void main() {
  test('legt beim Speichern einen neuen Mandanten an und verknüpft den Vorgang',
      () async {
    final datasource = _FakeVorgaengeDatasource();
    final vorgaenge = VorgangCubit(datasource, VorgangPersistenzFehlerCubit());
    final createMandant = _FakeCreateMandant();
    final bloc = _baue(vorgaenge, createMandant);

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

    await bloc.stream.firstWhere((s) => s is VorgangGespeichert);

    expect(createMandant.letzteAnfrage?.nachname, 'Müller');
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
  });

  test('SpeichereMandantEvent legt nur den Mandanten an (ohne Vorgang)',
      () async {
    final datasource = _FakeVorgaengeDatasource();
    final vorgaenge = VorgangCubit(datasource, VorgangPersistenzFehlerCubit());
    final createMandant = _FakeCreateMandant();
    final bloc = _baue(vorgaenge, createMandant);

    bloc.add(
      const SpeichereMandantEvent(
        neuerMandant: CreateMandantRequest(vorname: 'Max', nachname: 'Müller'),
      ),
    );

    final state = await bloc.stream.firstWhere((s) => s is MandantGespeichert)
        as MandantGespeichert;

    expect(state.warNeu, isTrue);
    expect(state.mandant.id, 7);
    expect(state.mandant.anzeigename, 'Max Müller');
    // Es wird kein Vorgang angelegt.
    expect(vorgaenge.state, isEmpty);
    expect(datasource.vorgaenge, isEmpty);

    await bloc.close();
    await vorgaenge.close();
  });

  test('speichert ohne Mandant nur den Vorgang (Nicht-Verkehrsrecht)', () async {
    final datasource = _FakeVorgaengeDatasource();
    final vorgaenge = VorgangCubit(datasource, VorgangPersistenzFehlerCubit());
    final createMandant = _FakeCreateMandant();
    final bloc = _baue(vorgaenge, createMandant);

    const daten = VorgangStartenDaten(
      auftragsnummer: 90,
      auftragsjahr: 26,
      abteilung: 'C03',
      rechtsgebiet: Rechtsgebiet.arbeitsrecht,
      referenz: '90/26 C03',
    );

    bloc.add(const SpeichereVorgangEvent(daten: daten));
    await bloc.stream.firstWhere((s) => s is VorgangGespeichert);

    expect(createMandant.letzteAnfrage, isNull);
    final vorgang = vorgaenge.state.single;
    expect(vorgang.referenz, '90/26 C03');
    expect(vorgang.mandantId, isNull);
    expect(vorgang.rechtsgebiet, Rechtsgebiet.arbeitsrecht);
    // Unfallfelder bleiben außerhalb von Verkehrsrecht leer.
    expect(vorgang.unfallort, isNull);

    await bloc.close();
    await vorgaenge.close();
  });
}
