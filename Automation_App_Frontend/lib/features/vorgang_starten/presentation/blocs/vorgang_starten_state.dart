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
///
/// [gespeicherterMandant] trägt den auf diesem Weg angelegten oder aktualisierten
/// Mandanten mit — sonst wüsste die View nichts davon, hielte ihn weiter für neu
/// und legte ihn beim nächsten Speichern ein zweites Mal an. Er ist der einzige
/// Unterschied zum Karten-Weg, der dafür `MandantGespeichert` meldet; beide
/// laufen in der View in dieselbe Nachbereitung.
final class VorgangGespeichert extends VorgangStartenState {
  final String referenz;
  final bool zentralrufAusgefuellt;

  /// Der bei diesem Speichern angelegte bzw. aktualisierte Mandant; null, wenn
  /// nur verknüpft oder gar kein Mandant erfasst wurde.
  final Mandant? gespeicherterMandant;

  const VorgangGespeichert({
    required this.referenz,
    this.zentralrufAusgefuellt = false,
    this.gespeicherterMandant,
  });

  @override
  List<Object?> get props => [
    referenz,
    zentralrufAusgefuellt,
    gespeicherterMandant,
  ];
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
