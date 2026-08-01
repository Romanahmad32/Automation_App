import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'ablage_state.dart';

/// Steuert die Akten-Ablage im Speicherschritt des Wizards (§3.6): lädt
/// Mandanten/Akten zur Auswahl, legt das fertige Dokument in der passenden Akte
/// ab und legt bei Bedarf zuvor einen neuen Mandanten an.
@injectable
class AblageCubit extends Cubit<AblageState> {
  final UseCase<List<Mandant>, NoParams> _getMandanten;
  final UseCase<List<Akte>, NoParams> _getAkten;
  final UseCase<Mandant, CreateMandantRequest> _createMandant;
  final UseCase<String, LegeDokumentAbParams> _legeDokumentAb;
  final KanzleiSettingsRepository _settingsRepository;

  AblageCubit(
    this._getMandanten,
    this._getAkten,
    this._createMandant,
    this._legeDokumentAb,
    this._settingsRepository,
  ) : super(const AblageState());

  Future<void> laden() async {
    emit(state.copyWith(status: AblageStatus.loading, message: () => null));

    final settings = await _settingsRepository.getSettings();
    final stammordner = switch (settings) {
      Right(value: final s) => s.aktenStammordner,
      Left() => '',
    };

    final mandantenResult = await _getMandanten(const NoParams());
    final mandanten = switch (mandantenResult) {
      Right(value: final m) => m,
      Left() => const <Mandant>[],
    };

    final aktenResult = await _getAkten(const NoParams());
    final akten = switch (aktenResult) {
      Right(value: final a) => a,
      Left() => const <Akte>[],
    };

    emit(
      state.copyWith(
        status: AblageStatus.ready,
        stammordner: stammordner,
        mandanten: mandanten,
        akten: akten,
      ),
    );
  }

  /// Ablage für einen bestehenden Mandanten.
  Future<void> ablegenFuerMandant({
    required int mandantId,
    required String aktenOrdnername,
    required String unterordnerName,
    required String quelldateiPfad,
  }) async {
    emit(state.copyWith(status: AblageStatus.filing, message: () => null));
    await _ablegen(
      mandantId: mandantId,
      aktenOrdnername: aktenOrdnername,
      unterordnerName: unterordnerName,
      quelldateiPfad: quelldateiPfad,
    );
  }

  /// Legt einen neuen Mandanten an und nimmt ihn in die Auswahl auf. Gibt den
  /// angelegten Mandanten zurück (oder null bei Fehler). Die Akte wird erst
  /// beim eigentlichen Ablegen verknüpft.
  Future<Mandant?> mandantAnlegen(CreateMandantRequest request) async {
    final result = await _createMandant(request);
    switch (result) {
      case Right(value: final mandant):
        emit(state.copyWith(mandanten: [mandant, ...state.mandanten]));
        return mandant;
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: AblageStatus.fehler,
            message: () => failure.message,
          ),
        );
        return null;
    }
  }

  Future<void> _ablegen({
    required int mandantId,
    required String aktenOrdnername,
    required String unterordnerName,
    required String quelldateiPfad,
  }) async {
    final result = await _legeDokumentAb(
      LegeDokumentAbParams(
        mandantId: mandantId,
        aktenOrdnername: aktenOrdnername,
        unterordnerName: unterordnerName,
        quelldateiPfad: quelldateiPfad,
      ),
    );
    switch (result) {
      case Right(value: final zielpfad):
        emit(
          state.copyWith(status: AblageStatus.erfolg, zielpfad: () => zielpfad),
        );
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: AblageStatus.fehler,
            message: () => failure.message,
          ),
        );
    }
  }
}
