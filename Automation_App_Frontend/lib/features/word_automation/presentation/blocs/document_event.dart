part of 'document_bloc.dart';

sealed class DocumentEvent {
  const DocumentEvent();
}

final class SelectDocumentEvent extends DocumentEvent {
  const SelectDocumentEvent();
}

/// Setzt den Dokumentpfad direkt (ohne Datei-Dialog) — z. B. wenn die
/// Word-Datei bereits an der gewählten Formularvorlage hinterlegt ist.
final class SetDocumentPathEvent extends DocumentEvent {
  final String path;

  const SetDocumentPathEvent(this.path);
}
