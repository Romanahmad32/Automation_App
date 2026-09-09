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

  /// True, wenn dieser Zustand aus der Ablage stammt: dieselbe Fassung, nur an
  /// ihrem Platz in der Akte. **Kein** neu erzeugtes Dokument — der Wizard
  /// bleibt deshalb im Speicherschritt stehen, statt zum Begutachten zu
  /// springen (§4.6).
  final bool inAkteAbgelegt;

  /// True, wenn dieser Zustand aus dem **Vorgang** stammt statt aus einem Lauf
  /// dieser Sitzung (§3: Wiederaufnahme). Der Unterschied trägt: Ein erzeugtes
  /// Dokument schaltet den Vorgang weiter, zählt die Schreiben-Nummer (§4.9)
  /// und springt ins Begutachten — ein wiederhergestelltes tut nichts davon,
  /// es macht nur die Schritte wieder erreichbar, die es schon gab.
  ///
  /// Die Warnungen der Erzeugung fehlen ihm: Sie stehen am Dokument, nicht am
  /// Vorgang. Was beim Erzeugen offenblieb, sieht man in der PDF-Vorschau.
  final bool wiederhergestellt;

  const EditedDocumentLoaded(
    this.path, {
    this.warnings = const [],
    this.erzeugtAm,
    this.inAkteAbgelegt = false,
    this.wiederhergestellt = false,
  });

  @override
  List<Object?> get props => [
    path,
    warnings,
    erzeugtAm,
    inAkteAbgelegt,
    wiederhergestellt,
  ];
}

final class EditedDocumentError extends EditedDocumentState {
  final String message;

  const EditedDocumentError(this.message);

  @override
  List<Object> get props => [message];
}

final class EditedDocumentLoading extends EditedDocumentState {}
