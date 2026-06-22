import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:automation_app/features/settings/domain/usecases/erhoehe_auftragsnummer.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/data/datasources/local_vorgaenge_datasource.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/offene_anfrage.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-Memory-Ersatz für die Datei-Persistenz.
class _FakeVorgaengeDatasource implements LocalVorgaengeDatasource {
  List<Vorgang> vorgaenge = const [];
  ZentralrufReplyData? vorgangsdaten;
  List<OffeneAnfrage> offeneAnfragen = const [];

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;

  @override
  Future<void> saveVorgaenge(List<Vorgang> neu) async => vorgaenge = neu;

  @override
  Future<ZentralrufReplyData?> loadVorgangsdaten() async => vorgangsdaten;

  @override
  Future<void> saveVorgangsdaten(ZentralrufReplyData? data) async =>
      vorgangsdaten = data;

  @override
  Future<List<OffeneAnfrage>> loadOffeneAnfragen() async => offeneAnfragen;

  @override
  Future<void> saveOffeneAnfragen(List<OffeneAnfrage> anfragen) async =>
      offeneAnfragen = anfragen;
}

/// In-Memory-Einstellungen, um das Hochzählen der Auftragsnummer zu prüfen.
class _FakeSettingsRepository implements KanzleiSettingsRepository {
  KanzleiSettings settings;

  _FakeSettingsRepository(this.settings);

  @override
  Future<Either<Failure, KanzleiSettings>> getSettings() async =>
      Right(settings);

  @override
  Future<Either<Failure, KanzleiSettings>> saveSettings(
    KanzleiSettings neu,
  ) async {
    settings = neu;
    return Right(neu);
  }
}

void main() {
  late _FakeVorgaengeDatasource datasource;
  late _FakeSettingsRepository settingsRepository;
  late VorgangCubit cubit;

  VorgangCubit baueCubit() => VorgangCubit(
    datasource,
    ErhoeheAuftragsnummer(settingsRepository),
  );

  setUp(() {
    datasource = _FakeVorgaengeDatasource();
    settingsRepository = _FakeSettingsRepository(
      const KanzleiSettings(laufendeAuftragsnummer: 84),
    );
    cubit = baueCubit();
  });

  tearDown(() => cubit.close());

  test('registriereAnfrage legt Vorgang an und persistiert ihn', () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.status, VorgangStatus.angefragt);
    expect(datasource.vorgaenge, hasLength(1));
  });

  test('gleiche Referenz wird nicht doppelt geführt', () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');

    expect(cubit.state, hasLength(1));
  });

  test('uebernehmeAntwort ordnet über die Referenz zu und schaltet weiter',
      () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(
        referenz: '84/26  c03_gg-ck 321',
        versichererName: 'HUK',
      ),
    );

    expect(cubit.state, hasLength(1));
    expect(cubit.state.single.status, VorgangStatus.beantwortet);
    expect(cubit.state.single.gegner, 'HUK');
  });

  test('uebernehmeAntwort ohne passende Anfrage legt eigenen Vorgang an',
      () async {
    await cubit.uebernehmeAntwort(
      const ZentralrufReplyData(
        referenz: '99/26 C03_HG-X 9',
        versichererName: 'Allianz',
      ),
    );

    expect(cubit.state, hasLength(1));
    final vorgang = cubit.state.single;
    expect(vorgang.referenz, '99/26 C03_HG-X 9');
    expect(vorgang.status, VorgangStatus.beantwortet);
    expect(vorgang.gegner, 'Allianz');
    expect(datasource.vorgaenge, hasLength(1));
  });

  test('findeZuReferenz ist tolerant bei Schreibweise und Whitespace',
      () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');

    expect(cubit.findeZuReferenz('84/26  c03_gg-ck 321 '), isNotNull);
    expect(cubit.findeZuReferenz('85/26 C03_GG-CK 321'), isNull);
    expect(cubit.findeZuReferenz(null), isNull);
  });

  test('stellt persistierte Vorgänge beim Erzeugen wieder her', () async {
    datasource.vorgaenge = [
      Vorgang.ausAnfrage(
        referenz: '12/26 C03_HG-E 1427',
        angefragtAm: DateTime(2026, 6, 1),
      ),
    ];

    final restored = baueCubit();
    // _restore läuft asynchron im Konstruktor an.
    await Future<void>.delayed(Duration.zero);

    expect(restored.state, hasLength(1));
    expect(restored.findeZuReferenz('12/26 C03_HG-E 1427'), isNotNull);
    await restored.close();
  });

  test('abschliessen schaltet auf versendet und zählt die Nummer hoch',
      () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');
    final vorgang = cubit.state.single;

    await cubit.abschliessen(vorgang);

    final abgeschlossen = cubit.findeZuReferenz('84/26 C03_GG-CK 321')!;
    expect(abgeschlossen.status, VorgangStatus.versendet);
    expect(abgeschlossen.abgeschlossenAm, isNotNull);
    expect(settingsRepository.settings.laufendeAuftragsnummer, 85);
  });

  test('abschliessen zählt einen bereits versendeten Vorgang nicht erneut hoch',
      () async {
    await cubit.registriereAnfrage('84/26 C03_GG-CK 321');
    await cubit.abschliessen(cubit.state.single);
    expect(settingsRepository.settings.laufendeAuftragsnummer, 85);

    // Erneuter Aufruf darf die Nummer nicht weiter erhöhen.
    await cubit.abschliessen(cubit.state.single);
    expect(settingsRepository.settings.laufendeAuftragsnummer, 85);
  });
}
