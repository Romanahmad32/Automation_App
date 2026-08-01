part of 'vorgang_starten_bloc.dart';

sealed class VorgangStartenState extends Equatable {
  const VorgangStartenState();

  @override
  List<Object?> get props => [];
}

final class VorgangStartenInitial extends VorgangStartenState {}

final class VorgangStartenLoading extends VorgangStartenState {}

/// Vorbelegung des Formulars aus den Einstellungen (laufende Auftragsnummer und
/// Abteilung). Wird beim Öffnen der Seite emittiert.
final class VorgangStartenDefaultsLoaded extends VorgangStartenState {
  final int auftragsnummer;
  final String abteilung;

  const VorgangStartenDefaultsLoaded({
    required this.auftragsnummer,
    required this.abteilung,
  });

  @override
  List<Object?> get props => [auftragsnummer, abteilung];
}

/// Der Vorgang wurde gespeichert. [zentralrufAusgefuellt] zeigt an, ob zusätzlich
/// das Zentralruf-Formular im Browser vorbefüllt wurde (dann anderer Hinweistext).
final class VorgangGespeichert extends VorgangStartenState {
  final String referenz;
  final bool zentralrufAusgefuellt;

  const VorgangGespeichert({
    required this.referenz,
    this.zentralrufAusgefuellt = false,
  });

  @override
  List<Object?> get props => [referenz, zentralrufAusgefuellt];
}

/// Der Mandant wurde eigenständig (über den Karten-Button) gespeichert.
/// [warNeu] = true bei Neuanlage, sonst Aktualisierung. Die View übernimmt den
/// Mandanten danach in die Auswahl.
final class MandantGespeichert extends VorgangStartenState {
  final Mandant mandant;
  final bool warNeu;

  const MandantGespeichert(this.mandant, {required this.warNeu});

  @override
  List<Object?> get props => [mandant, warNeu];
}

final class VorgangStartenError extends VorgangStartenState {
  final String message;

  const VorgangStartenError(this.message);

  @override
  List<Object?> get props => [message];
}
