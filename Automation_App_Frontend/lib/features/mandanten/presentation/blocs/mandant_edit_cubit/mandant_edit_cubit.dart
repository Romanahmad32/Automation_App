import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'mandant_edit_state.dart';

/// Anlegen und Bearbeiten eines einzelnen Mandanten (Detailseite).
@injectable
class MandantEditCubit extends Cubit<MandantEditState> {
  final UseCase<Mandant, CreateMandantRequest> _createMandant;
  final UseCase<Mandant, Mandant> _updateMandant;

  MandantEditCubit(this._createMandant, this._updateMandant)
    : super(const MandantEditState());

  Future<void> erstelle(CreateMandantRequest request) async {
    emit(state.copyWith(status: MandantEditStatus.saving, message: () => null));
    final result = await _createMandant(request);
    switch (result) {
      case Right():
        emit(state.copyWith(status: MandantEditStatus.success));
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: MandantEditStatus.failure,
            message: () => failure.message,
          ),
        );
    }
  }

  Future<void> aktualisiere(Mandant mandant) async {
    emit(state.copyWith(status: MandantEditStatus.saving, message: () => null));
    final result = await _updateMandant(mandant);
    switch (result) {
      case Right():
        emit(state.copyWith(status: MandantEditStatus.success));
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: MandantEditStatus.failure,
            message: () => failure.message,
          ),
        );
    }
  }
}
