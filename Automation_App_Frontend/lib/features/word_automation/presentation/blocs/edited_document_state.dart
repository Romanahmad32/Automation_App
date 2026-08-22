part of 'edited_document_bloc.dart';

sealed class EditedDocumentState extends Equatable {
  const EditedDocumentState();

  @override
  List<Object?> get props => [];
}

final class EditedDocumentInitial extends EditedDocumentState {}

final class EditedDocumentLoaded extends EditedDocumentState {
  final String path;

  /// Warnungen aus dem Backend, v. a. nicht ersetzte Platzhalter (Anf. 3.4).
  final List<String> warnings;

  /// Änderungszeit der Datei unmittelbar nach der Erzeugung. Weicht sie später
  /// ab, hat jemand das Dokument angefasst (typisch: „In Word öffnen" im
  /// Prüfschritt) — dann fragt `darfNeuErzeugen` vor dem Überschreiben nach.
  /// Null, wenn sie sich nicht lesen liess.
  final DateTime? erzeugtAm;

  const EditedDocumentLoaded(
    this.path, {
    this.warnings = const [],
    this.erzeugtAm,
  });

  @override
  List<Object?> get props => [path, warnings, erzeugtAm];
}

final class EditedDocumentError extends EditedDocumentState {
  final String message;

  const EditedDocumentError(this.message);

  @override
  List<Object> get props => [message];
}

final class EditedDocumentLoading extends EditedDocumentState {}
