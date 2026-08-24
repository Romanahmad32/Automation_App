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

  /// Was von der laufenden Ablage noch aussteht. Eine Ablage kann mehrere
  /// Dateien umfassen (Word und PDF derselben Fassung); sie laufen
  /// nacheinander, damit jede ihre eigene Rückfrage bekommen kann.
  final List<LegeDokumentAbParams> _warteschlange = [];

  /// Was von der laufenden Ablage bereits in der Akte liegt.
  final List<String> _abgelegt = [];

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
    _warteschlange.clear();
    _abgelegt.clear();
    _offeneAblage = null;
    emit(
      state.copyWith(
        status: AblageStatus.loading,
        message: () => null,
        zielpfade: const [],
        konfliktPfad: () => null,
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
  /// Fassungen, die in denselben Fall-Ordner sollen (Word, PDF oder beide) —
  /// sie werden der Reihe nach abgelegt, deshalb die bearbeitbare zuerst.
  ///
  /// Liegt im Fall-Ordner schon eine gleichnamige Datei, hält die Ablage bei
  /// dieser Datei in [AblageStatus.konflikt] an; die Oberfläche fragt nach und
  /// ruft [konfliktLoesen] bzw. [konfliktAbbrechen].
  Future<void> ablegenFuerMandant({
    required int mandantId,
    required String aktenOrdnername,
    required String unterordnerName,
    required List<String> quelldateiPfade,
    AblageStrategie strategie = AblageStrategie.fragen,
  }) async {
    if (quelldateiPfade.isEmpty) return;
    _abgelegt.clear();
    _warteschlange
      ..clear()
      ..addAll([
        for (final pfad in quelldateiPfade)
          LegeDokumentAbParams(
            mandantId: mandantId,
            aktenOrdnername: aktenOrdnername,
            unterordnerName: unterordnerName,
            quelldateiPfad: pfad,
            strategie: strategie,
          ),
      ]);
    emit(
      state.copyWith(
        status: AblageStatus.filing,
        message: () => null,
        zielpfade: const [],
      ),
    );
    await _naechsteQuelle();
  }

  /// Zweiter Anlauf nach der Rückfrage, mit der Entscheidung des Anwalts.
  Future<void> konfliktLoesen(AblageStrategie strategie) async {
    final offen = _offeneAblage;
    if (offen == null) return;
    emit(state.copyWith(status: AblageStatus.filing, message: () => null));
    await _ablegen(offen.mitStrategie(strategie));
  }

  /// Der Anwalt hat die Rückfrage abgebrochen: für *diese* Datei wurde nichts
  /// geschrieben, und die noch ausstehenden entfallen. Was vorher schon in der
  /// Akte gelandet ist, bleibt dort — und wird als Erfolg gemeldet, damit der
  /// Wizard es nicht übersieht.
  void konfliktAbbrechen() {
    if (state.status != AblageStatus.konflikt) return;
    _offeneAblage = null;
    _warteschlange.clear();
    emit(
      state.copyWith(
        status: _abgelegt.isEmpty ? AblageStatus.ready : AblageStatus.erfolg,
        zielpfade: List.of(_abgelegt),
        konfliktPfad: () => null,
      ),
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

  /// Nimmt sich die nächste ausstehende Quelldatei vor — oder meldet Erfolg,
  /// wenn alle in der Akte liegen.
  Future<void> _naechsteQuelle() async {
    if (_warteschlange.isEmpty) {
      emit(
        state.copyWith(
          status: AblageStatus.erfolg,
          zielpfade: List.of(_abgelegt),
          konfliktPfad: () => null,
        ),
      );
      return;
    }
    await _ablegen(_warteschlange.removeAt(0));
  }

  Future<void> _ablegen(LegeDokumentAbParams params) async {
    final result = await _legeDokumentAb(params);
    switch (result) {
      case Right(value: final ergebnis) when ergebnis.konflikt:
        _offeneAblage = params;
        emit(
          state.copyWith(
            status: AblageStatus.konflikt,
            konfliktPfad: () => ergebnis.zielpfad,
          ),
        );
      case Right(value: final ergebnis):
        _offeneAblage = null;
        _abgelegt.add(ergebnis.zielpfad);
        await _naechsteQuelle();
      case Left(value: final failure):
        // Was schon in der Akte liegt, bleibt dort — das gehört in die
        // Meldung, sonst legt der Anwalt es ein zweites Mal ab.
        _warteschlange.clear();
        final bereits = _abgelegt.isEmpty
            ? ''
            : ' Bereits abgelegt: ${_abgelegt.join(', ')}.';
        emit(
          state.copyWith(
            status: AblageStatus.fehler,
            message: () => '${failure.message}$bereits',
          ),
        );
    }
  }
}
