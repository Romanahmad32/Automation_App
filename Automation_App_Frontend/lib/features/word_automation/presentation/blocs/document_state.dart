part of 'document_bloc.dart';

sealed class DocumentState extends Equatable {
  const DocumentState();
}

final class DocumentInitial extends DocumentState {
  @override
  List<Object> get props => [];
}

final class DocumentLoading extends DocumentState {
  @override
  List<Object> get props => [];
}

final class DocumentLoaded extends DocumentState {
  final String path;

  const DocumentLoaded({required this.path});

  @override
  List<Object> get props => [path];
}

final class DocumentError extends DocumentState {
  final String message;

  const DocumentError(this.message);

  @override
  List<Object> get props => [message];
}
