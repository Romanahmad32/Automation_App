part of 'edited_document_bloc.dart';

sealed class EditedDocumentEvent extends Equatable {
  const EditedDocumentEvent();
}

final class EditDocumentEvent extends EditedDocumentEvent {
  final String path;
  final Map<String, String> data;
  final DamageListing? damageListing;
  final bool? vorsteuerabzugsberechtigt;
  final String? outputFileName;

  const EditDocumentEvent({
    required this.data,
    required this.path,
    this.damageListing,
    this.vorsteuerabzugsberechtigt,
    this.outputFileName,
  });

  @override
  List<Object?> get props =>
      [
        path,
        data,
        damageListing,
        vorsteuerabzugsberechtigt,
        outputFileName,
      ];
}
