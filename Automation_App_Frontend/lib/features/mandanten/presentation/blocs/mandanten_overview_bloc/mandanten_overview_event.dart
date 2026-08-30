part of 'mandanten_overview_bloc.dart';

sealed class MandantenOverviewEvent extends Equatable {
  const MandantenOverviewEvent();

  @override
  List<Object> get props => [];
}

/// Lädt Mandantenregister und Akten-Scan neu.
final class LoadMandantenUebersichtEvent extends MandantenOverviewEvent {
  /// Nur das Register neu holen und den vorhandenen Akten-Scan behalten. Für
  /// alles, was nur die Datenbank ändert (Mandant angelegt oder bearbeitet):
  /// am Dateisystem hat sich dabei nichts getan, und der Scan ist der teure
  /// Teil.
  final bool nurRegister;

  const LoadMandantenUebersichtEvent({this.nurRegister = false});

  @override
  List<Object> get props => [nurRegister];
}

/// Aktualisiert die Mandantensuche. Leerer String zeigt wieder alle.
///
/// Die Suche läuft im Dienst über den **ganzen** Bestand, nicht über die schon
/// geladenen Seiten — sie holt deshalb die erste Seite neu, statt im Speicher
/// zu filtern.
final class SearchMandantenEvent extends MandantenOverviewEvent {
  final String query;

  const SearchMandantenEvent(this.query);

  @override
  List<Object> get props => [query];
}

/// Holt die nächste Seite der Mandantenliste — ausgelöst vom Weiterscrollen.
final class LadeWeitereMandantenEvent extends MandantenOverviewEvent {
  const LadeWeitereMandantenEvent();
}

/// Nimmt die Fehlermeldung einer einzelnen Aktion weg. Der geladene Stand
/// bleibt dabei unberührt — er war nie weg.
final class FehlerVerwerfenEvent extends MandantenOverviewEvent {
  const FehlerVerwerfenEvent();
}

/// Setzt Suche, Aktentyp- und Zeitfilter des Zuordnungsstapels neu.
final class SetzeZuordnungFilterEvent extends MandantenOverviewEvent {
  final ZuordnungFilter filter;

  const SetzeZuordnungFilterEvent(this.filter);

  @override
  List<Object> get props => [filter];
}

/// Lädt die Fälle einer Akte nach (beim Aufklappen). Ist bereits geladen,
/// passiert nichts.
final class LadeFaelleEvent extends MandantenOverviewEvent {
  final Akte akte;

  const LadeFaelleEvent(this.akte);

  @override
  List<Object> get props => [akte];
}

/// Setzt oder nimmt den Vermerk „ohne Mandantenbezug" zurück — für einen
/// Ordner oder für den ganzen gerade gefilterten Stapel. [art] `null` heißt:
/// zurück in den Zuordnungsstapel.
final class SetzeOrdnerStatusEvent extends MandantenOverviewEvent {
  final List<String> ordnernamen;
  final OrdnerStatusArt? art;

  const SetzeOrdnerStatusEvent({required this.ordnernamen, required this.art});

  @override
  List<Object> get props => [ordnernamen, art ?? ''];
}

final class DeleteMandantEvent extends MandantenOverviewEvent {
  final int mandantId;

  const DeleteMandantEvent(this.mandantId);

  @override
  List<Object> get props => [mandantId];
}

/// Ordnet einem bestehenden Mandanten einen noch nicht zugeordneten Ordner zu.
final class VerknuepfeOrdnerEvent extends MandantenOverviewEvent {
  final int mandantId;
  final String ordnername;

  const VerknuepfeOrdnerEvent({
    required this.mandantId,
    required this.ordnername,
  });

  @override
  List<Object> get props => [mandantId, ordnername];
}
