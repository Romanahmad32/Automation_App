part of 'template_placeholders_bloc.dart';

/// Ergebnis der Platzhalter-Erkennung für **eine** Datei (einen Slot).
sealed class SlotPlaceholders extends Equatable {
  const SlotPlaceholders();

  @override
  List<Object?> get props => [];
}

final class SlotPlaceholdersInitial extends SlotPlaceholders {
  const SlotPlaceholdersInitial();
}

final class SlotPlaceholdersLoading extends SlotPlaceholders {
  const SlotPlaceholdersLoading();
}

final class SlotPlaceholdersLoaded extends SlotPlaceholders {
  final List<String> placeholders;

  const SlotPlaceholdersLoaded(this.placeholders);

  @override
  List<Object?> get props => [placeholders];
}

final class SlotPlaceholdersError extends SlotPlaceholders {
  final String message;

  const SlotPlaceholdersError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Gesamtzustand: Platzhalter-Ergebnis je Slot (ohne / mit Auflistung).
final class TemplatePlaceholdersState extends Equatable {
  final Map<TemplateFileSlot, SlotPlaceholders> slots;

  const TemplatePlaceholdersState({this.slots = const {}});

  /// Ergebnis für [slot]; [SlotPlaceholdersInitial], solange nichts geladen wurde.
  SlotPlaceholders forSlot(TemplateFileSlot slot) =>
      slots[slot] ?? const SlotPlaceholdersInitial();

  TemplatePlaceholdersState withSlot(
    TemplateFileSlot slot,
    SlotPlaceholders result,
  ) {
    return TemplatePlaceholdersState(slots: {...slots, slot: result});
  }

  @override
  List<Object?> get props => [slots];
}
