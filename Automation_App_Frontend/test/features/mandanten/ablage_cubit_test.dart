import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/entities/ordner_zustand.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fallOrdner = r'C:\Akten\Mustermann\Unfall';
const String _wordQuelle = r'C:\App\Generated\Arbeit\84-26 C03\Brief.docx';
const String _pdfQuelle = r'C:\App\Generated\Arbeit\84-26 C03\Brief.pdf';

/// Legt ab, was ihm gereicht wird — und meldet eine Rückfrage, sobald eine der
/// Zieldateien in [vorhandene] steht und keine Strategie mitkommt.
class _FakeLegeDokumentAb
    implements UseCase<AblageErgebnis, LegeDokumentAbParams> {
  final Set<String> vorhandene;
  final List<LegeDokumentAbParams> aufrufe = [];

  _FakeLegeDokumentAb({this.vorhandene = const {}});

  @override
  Future<Either<Failure, AblageErgebnis>> call(
    LegeDokumentAbParams params,
  ) async {
    aufrufe.add(params);
    final ziele = [
      for (final quelle in params.quelldateiPfade)
        '$_fallOrdner\\${quelle.split(RegExp(r'[\\/]')).last}',
    ];
    final belegt = [
      for (final ziel in ziele)
        if (vorhandene.contains(ziel)) ziel,
    ];
    if (belegt.isNotEmpty && params.strategie == AblageStrategie.fragen) {
      return Right(AblageErgebnis.konfliktMit(belegt));
    }
    return Right(AblageErgebnis.abgelegt(ziele));
  }
}

/// Die Auswahlquellen des Cubits werden in diesen Tests nicht gebraucht:
/// geprüft wird die Ablage selbst, nicht das Laden der Listen.
class _NichtGebraucht<T, P> implements UseCase<T, P> {
  @override
  Future<Either<Failure, T>> call(P params) =>
      throw UnimplementedError('wird in diesem Test nicht aufgerufen');
}

class _NichtGebrauchteSettings implements KanzleiSettingsRepository {
  @override
  Future<Either<Failure, KanzleiSettings>> getSettings() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, KanzleiSettings>> saveSettings(
    KanzleiSettings settings,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, KanzleiSettings>> erhoeheAuftragsnummer() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<OrdnerZustand>>> ordnerZustand() =>
      throw UnimplementedError();
}

AblageCubit cubitMit(UseCase<AblageErgebnis, LegeDokumentAbParams> ablage) =>
    AblageCubit(
      _NichtGebraucht<List<Mandant>, NoParams>(),
      _NichtGebraucht<List<Akte>, NoParams>(),
      _NichtGebraucht<List<Fall>, GetFaelleParams>(),
      _NichtGebraucht<Mandant, CreateMandantRequest>(),
      ablage,
      _NichtGebrauchteSettings(),
    );

Future<void> ablegen(AblageCubit cubit, List<String> quellen) =>
    cubit.ablegenFuerMandant(
      mandantId: 1,
      aktenOrdnername: 'Mustermann',
      unterordnerName: 'Unfall',
      quelldateiPfade: quellen,
    );

void main() {
  test(
    'legt beide Fassungen in einem Zug ab und meldet beide Zielpfade',
    () async {
      final ablage = _FakeLegeDokumentAb();
      final cubit = cubitMit(ablage);

      await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

      expect(cubit.state.status, AblageStatus.erfolg);
      expect(cubit.state.zielpfade, [
        '$_fallOrdner\\Brief.docx',
        '$_fallOrdner\\Brief.pdf',
      ]);
      // Eine Anfrage fuer das ganze Schreiben, nicht eine je Datei: nur so kann
      // der Anwalt einmal entscheiden und beide Fassungen behalten den Namen.
      expect(ablage.aufrufe, hasLength(1));
    },
  );

  test('meldet den Konflikt fuer das ganze Schreiben', () async {
    final cubit = cubitMit(
      _FakeLegeDokumentAb(vorhandene: {'$_fallOrdner\\Brief.pdf'}),
    );

    await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

    expect(cubit.state.status, AblageStatus.konflikt);
    expect(cubit.state.konfliktPfade, ['$_fallOrdner\\Brief.pdf']);
    // Vor der Entscheidung ist nichts geschrieben — auch die Word-Fassung
    // nicht, die fuer sich genommen gepasst haette.
    expect(cubit.state.zielpfade, isEmpty);
  });

  test('nach dem Abbruch bleibt die Akte unveraendert', () async {
    final cubit = cubitMit(
      _FakeLegeDokumentAb(vorhandene: {'$_fallOrdner\\Brief.pdf'}),
    );
    await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

    cubit.konfliktAbbrechen();

    expect(cubit.state.status, AblageStatus.ready);
    expect(cubit.state.zielpfade, isEmpty);
    expect(cubit.state.konfliktPfade, isEmpty);
  });

  test('konfliktLoesen legt beide Fassungen doch ab', () async {
    final cubit = cubitMit(
      _FakeLegeDokumentAb(vorhandene: {'$_fallOrdner\\Brief.pdf'}),
    );
    await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

    await cubit.konfliktLoesen(AblageStrategie.ersetzen);

    expect(cubit.state.status, AblageStatus.erfolg);
    expect(cubit.state.zielpfade, [
      '$_fallOrdner\\Brief.docx',
      '$_fallOrdner\\Brief.pdf',
    ]);
  });
}
