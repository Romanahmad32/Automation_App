import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'ablage_state.dart';

/// Steuert die Akten-Ablage im Speicherschritt des Wizards (§6.1): lädt
/// Mandanten/Akten zur Auswahl, legt das fertige Dokument in der passenden Akte
/// ab und legt bei Bedarf zuvor einen neuen Mandanten an.
@injectable
class AblageCubit extends Cubit<AblageState> {
  final UseCase<List<Mandant>, NoParams> _getMandanten;
  final UseCase<List<Akte>, NoParams> _getAkten;
  final UseCase<Mandant, CreateMandantRequest> _createMandant;
  final UseCase<AblageErgebnis, LegeDokumentAbParams> _legeDokumentAb;
  final KanzleiSettingsRepository _settingsRepository;

  /// Die Anfrage, die zur Rückfrage geführt hat. Gemerkt, damit der zweite
  /// Anlauf genau dieselbe ist: Die Eingaben im Formular können sich inzwischen
  /// geändert haben, entschieden hat der Anwalt aber über *diese* Ablage.
  LegeDokumentAbParams? _offeneAblage;

  AblageCubit(
    this._getMandanten,
    this._getAkten,
    this._createMandant,
    this._legeDokumentAb,
    this._settingsRepository,
  ) : super(const AblageState());

  Future<void> laden() async {
    // Auch der Weg zurück aus einer fertigen Ablage („Erneut ablegen"): das
    // Ergebnis der vorigen gehört dann nicht mehr in den Zustand.
    _offeneAblage = null;
    emit(
      state.copyWith(
        status: AblageStatus.loading,
        message: () => null,
        zielpfade: const [],
        konfliktPfade: const [],
      ),
    );

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

  /// Ablage für einen bestehenden Mandanten. [quelldateiPfade] sind die
  /// Fassungen desselben Schreibens (Word, PDF oder beide); sie gehen als ein
  /// Vorgang in denselben Fall-Ordner.
  ///
  /// Liegt dort schon eine gleichnamige Datei, endet der Aufruf in
  /// [AblageStatus.konflikt] — geschrieben ist dann **nichts**; die Oberfläche
  /// fragt nach und ruft [konfliktLoesen] bzw. [konfliktAbbrechen].
  Future<void> ablegenFuerMandant({
    required int mandantId,
    required String aktenOrdnername,
    required String unterordnerName,
    required List<String> quelldateiPfade,
    AblageStrategie strategie = AblageStrategie.fragen,
  }) async {
    if (quelldateiPfade.isEmpty) return;
    emit(
      state.copyWith(
        status: AblageStatus.filing,
        message: () => null,
        zielpfade: const [],
      ),
    );
    await _ablegen(
      LegeDokumentAbParams(
        mandantId: mandantId,
        aktenOrdnername: aktenOrdnername,
        unterordnerName: unterordnerName,
        quelldateiPfade: quelldateiPfade,
        strategie: strategie,
      ),
    );
  }

  /// Zweiter Anlauf nach der Rückfrage, mit der Entscheidung des Anwalts.
  Future<void> konfliktLoesen(AblageStrategie strategie) async {
    final offen = _offeneAblage;
    if (offen == null) return;
    emit(state.copyWith(status: AblageStatus.filing, message: () => null));
    await _ablegen(offen.mitStrategie(strategie));
  }

  /// Der Anwalt hat die Rückfrage abgebrochen: zurück zur Auswahl, ohne dass
  /// etwas geschrieben wurde — auch keine der weiteren Fassungen.
  void konfliktAbbrechen() {
    if (state.status != AblageStatus.konflikt) return;
    _offeneAblage = null;
    emit(state.copyWith(status: AblageStatus.ready, konfliktPfade: const []));
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

  Future<void> _ablegen(LegeDokumentAbParams params) async {
    final result = await _legeDokumentAb(params);
    switch (result) {
      case Right(value: final ergebnis) when ergebnis.konflikt:
        _offeneAblage = params;
        emit(
          state.copyWith(
            status: AblageStatus.konflikt,
            konfliktPfade: ergebnis.konfliktPfade,
          ),
        );
      case Right(value: final ergebnis):
        _offeneAblage = null;
        emit(
          state.copyWith(
            status: AblageStatus.erfolg,
            zielpfade: ergebnis.zielpfade,
            konfliktPfade: const [],
          ),
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
