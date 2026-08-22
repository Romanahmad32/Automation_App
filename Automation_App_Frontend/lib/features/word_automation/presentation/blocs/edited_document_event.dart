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

  /// Referenz des Vorgangs — bestimmt den Arbeitsordner im Backend.
  final String? vorgangSchluessel;

  const EditDocumentEvent({
    required this.data,
    required this.path,
    this.damageListing,
    this.vorsteuerabzugsberechtigt,
    this.outputFileName,
    this.vorgangSchluessel,
  });

  @override
  List<Object?> get props => [
    path,
    data,
    damageListing,
    vorsteuerabzugsberechtigt,
    outputFileName,
    vorgangSchluessel,
  ];
}

/// Das Dokument liegt jetzt in der Akte: ab hier arbeitet der Wizard mit der
/// abgelegten Datei weiter, nicht mehr mit der Arbeitskopie — die wird nach der
/// Ablage gelöscht (§4.6), und ein Pfad, hinter dem nichts mehr liegt, ließe
/// „In Word öffnen" und „An anderen Ort speichern" ins Leere laufen.
final class DokumentAbgelegtEvent extends EditedDocumentEvent {
  final String zielpfad;

  const DokumentAbgelegtEvent(this.zielpfad);

  @override
  List<Object?> get props => [zielpfad];
}
