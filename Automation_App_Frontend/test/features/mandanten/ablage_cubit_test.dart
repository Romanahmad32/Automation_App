import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fallOrdner = r'C:\Akten\Mustermann\Unfall';
const String _wordQuelle = r'C:\App\Generated\Arbeit\84-26 C03\Brief.docx';
const String _pdfQuelle = r'C:\App\Generated\Arbeit\84-26 C03\Brief.pdf';

/// Legt ab, was ihm gereicht wird — und meldet für jeden Pfad in
/// [vorhandene] eine Rückfrage, solange keine Strategie mitkommt.
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
    final name = params.quelldateiPfad.split(RegExp(r'[\\/]')).last;
    final ziel = '$_fallOrdner\\$name';
    if (vorhandene.contains(ziel) &&
        params.strategie == AblageStrategie.fragen) {
      return Right(AblageErgebnis.konfliktMit(ziel));
    }
    return Right(AblageErgebnis.abgelegt(ziel));
  }
}

class _FehlschlagendeAblage
    implements UseCase<AblageErgebnis, LegeDokumentAbParams> {
  final String scheitertAn;

  _FehlschlagendeAblage(this.scheitertAn);

  @override
  Future<Either<Failure, AblageErgebnis>> call(
    LegeDokumentAbParams params,
  ) async {
    if (params.quelldateiPfad.endsWith(scheitertAn)) {
      return Left(LocalFailure(message: 'Quelldatei nicht gefunden'));
    }
    final name = params.quelldateiPfad.split(RegExp(r'[\\/]')).last;
    return Right(AblageErgebnis.abgelegt('$_fallOrdner\\$name'));
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
}

AblageCubit cubitMit(UseCase<AblageErgebnis, LegeDokumentAbParams> ablage) =>
    AblageCubit(
      _NichtGebraucht<List<Mandant>, NoParams>(),
      _NichtGebraucht<List<Akte>, NoParams>(),
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
    'legt beide Fassungen nacheinander ab und meldet beide Zielpfade',
    () async {
      final ablage = _FakeLegeDokumentAb();
      final cubit = cubitMit(ablage);

      await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

      expect(cubit.state.status, AblageStatus.erfolg);
      expect(cubit.state.zielpfade, [
        '$_fallOrdner\\Brief.docx',
        '$_fallOrdner\\Brief.pdf',
      ]);
      // Reihenfolge zählt: die Word-Fassung zuerst, damit bei einer Rückfrage
      // zur zweiten Datei die bearbeitbare schon in der Akte liegt.
      expect(ablage.aufrufe.first.quelldateiPfad, _wordQuelle);
    },
  );

  test('hält bei der Datei an, die schon in der Akte liegt', () async {
    final ablage = _FakeLegeDokumentAb(vorhandene: {'$_fallOrdner\\Brief.pdf'});
    final cubit = cubitMit(ablage);

    await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

    expect(cubit.state.status, AblageStatus.konflikt);
    expect(cubit.state.konfliktPfad, '$_fallOrdner\\Brief.pdf');
  });

  test(
    'nach dem Abbruch der Rückfrage bleibt die erste Fassung abgelegt',
    () async {
      final cubit = cubitMit(
        _FakeLegeDokumentAb(vorhandene: {'$_fallOrdner\\Brief.pdf'}),
      );
      await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

      cubit.konfliktAbbrechen();

      // Die Word-Fassung liegt in der Akte — das darf der Wizard nicht
      // uebersehen, sonst bleibt der Vorgang auf „erstellt" stehen.
      expect(cubit.state.status, AblageStatus.erfolg);
      expect(cubit.state.zielpfade, ['$_fallOrdner\\Brief.docx']);
    },
  );

  test('konfliktLoesen legt die zurückgestellte Fassung doch ab', () async {
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

  test('scheitert die zweite Fassung, nennt die Meldung die erste', () async {
    final cubit = cubitMit(_FehlschlagendeAblage('.pdf'));

    await ablegen(cubit, [_wordQuelle, _pdfQuelle]);

    expect(cubit.state.status, AblageStatus.fehler);
    expect(cubit.state.message, contains('Brief.docx'));
  });
}
