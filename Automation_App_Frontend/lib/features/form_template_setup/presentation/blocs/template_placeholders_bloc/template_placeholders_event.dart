part of 'template_placeholders_bloc.dart';

/// Welche der beiden Word-Dateien einer Vorlage gemeint ist.
enum TemplateFileSlot { ohneAuflistung, mitAuflistung }

sealed class TemplatePlaceholdersEvent extends Equatable {
  const TemplatePlaceholdersEvent();
}

/// Lädt die {{Platzhalter}} der Datei [wordFilePath] in den angegebenen [slot].
final class LoadTemplatePlaceholders extends TemplatePlaceholdersEvent {
  final String wordFilePath;
  final TemplateFileSlot slot;

  const LoadTemplatePlaceholders(this.wordFilePath, this.slot);

  @override
  List<Object?> get props => [wordFilePath, slot];
}

/// Setzt einen Slot zurück (z. B. wenn die Verknüpfung entfernt wurde).
final class ClearTemplatePlaceholders extends TemplatePlaceholdersEvent {
  final TemplateFileSlot slot;

  const ClearTemplatePlaceholders(this.slot);

  @override
  List<Object?> get props => [slot];
}
