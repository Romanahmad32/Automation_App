part of 'zentralruf_bloc.dart';

sealed class ZentralrufState extends Equatable {
  const ZentralrufState();

  @override
  List<Object> get props => [];
}

final class ZentralrufInitial extends ZentralrufState {}

final class ZentralrufLoading extends ZentralrufState {}

/// Vorbelegung des Formulars aus den Einstellungen (laufende Auftragsnummer und
/// Abteilung). Wird beim Öffnen der Seite emittiert, damit das Formular den
/// aktuellen Wert anzeigt.
final class ZentralrufDefaultsLoaded extends ZentralrufState {
  final int auftragsnummer;
  final String abteilung;

  const ZentralrufDefaultsLoaded({
    required this.auftragsnummer,
    required this.abteilung,
  });

  @override
  List<Object> get props => [auftragsnummer, abteilung];
}

final class ZentralrufPrefillSuccess extends ZentralrufState {
  final ZentralrufPrefillResult result;

  const ZentralrufPrefillSuccess(this.result);

  @override
  List<Object> get props => [result.referenz];
}

final class ZentralrufError extends ZentralrufState {
  final String message;

  const ZentralrufError(this.message);

  @override
  List<Object> get props => [message];
}
