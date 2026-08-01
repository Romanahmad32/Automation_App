part of 'mandant_edit_cubit.dart';

enum MandantEditStatus { initial, saving, success, failure }

class MandantEditState extends Equatable {
  final MandantEditStatus status;
  final String? message;

  const MandantEditState({
    this.status = MandantEditStatus.initial,
    this.message,
  });

  MandantEditState copyWith({
    MandantEditStatus? status,
    String? Function()? message,
  }) {
    return MandantEditState(
      status: status ?? this.status,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}
