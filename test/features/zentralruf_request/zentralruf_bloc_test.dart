import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/data/datasources/local_vorgaenge_datasource.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/offene_anfrage.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/offene_anfragen_cubit.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/zentralruf_request/presentation/blocs/zentralruf_bloc.dart';
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

/// Liefert immer Left → der Bloc nimmt den einfachen Pfad ohne
/// Auftragsnummer-Fortzählung (für diesen Test irrelevant).
class _FakeGetSettings implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Left(LocalFailure(message: 'keine Einstellungen'));
}

class _FakeSaveSettings implements UseCase<KanzleiSettings, KanzleiSettings> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) async =>
      Right(params);
}

class _FakeVorgaengeDatasource implements LocalVorgaengeDatasource {
  List<Vorgang> vorgaenge = const [];

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;

  @override
  Future<void> saveVorgaenge(List<Vorgang> neu) async => vorgaenge = neu;

  @override
  Future<ZentralrufReplyData?> loadVorgangsdaten() async => null;

  @override
  Future<void> saveVorgangsdaten(ZentralrufReplyData? data) async {}

  @override
  Future<List<OffeneAnfrage>> loadOffeneAnfragen() async => const [];

  @override
  Future<void> saveOffeneAnfragen(List<OffeneAnfrage> anfragen) async {}
}

void main() {
  test(
    'legt beim Prefill einen Vorgang mit Mandant-Verknüpfung und Rechtsgebiet an',
    () async {
      final datasource = _FakeVorgaengeDatasource();
      final vorgaenge = VorgangCubit(datasource);
      final offene = OffeneAnfragenCubit(datasource);
      final bloc = ZentralrufBloc(
        _FakePrefill(
          const ZentralrufPrefillResult(
            referenz: '84/26 C03_GG-CK 321',
            filledFields: [],
            skippedFields: [],
          ),
        ),
        _FakeGetSettings(),
        _FakeSaveSettings(),
        offene,
        vorgaenge,
      );

      bloc.add(
        PrefillZentralrufFormEvent(
          request: ZentralrufRequest(
            auftragsnummer: 84,
            abteilung: 'C03',
            kennzeichenSchaediger: 'GG-CK 321',
            schadentag: DateTime(2026, 6, 20),
          ),
          mandantId: 7,
          mandantName: 'Max Müller',
          rechtsgebiet: Rechtsgebiet.strafrecht,
        ),
      );

      await bloc.stream.firstWhere((s) => s is ZentralrufPrefillSuccess);

      expect(vorgaenge.state, hasLength(1));
      final vorgang = vorgaenge.state.single;
      expect(vorgang.referenz, '84/26 C03_GG-CK 321');
      expect(vorgang.status, VorgangStatus.angefragt);
      expect(vorgang.mandantId, 7);
      expect(vorgang.mandantName, 'Max Müller');
      expect(vorgang.rechtsgebiet, Rechtsgebiet.strafrecht);
      // Der Vorgang wurde auch persistiert.
      expect(datasource.vorgaenge, hasLength(1));

      await bloc.close();
      await vorgaenge.close();
      await offene.close();
    },
  );
}
