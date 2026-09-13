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

/// Zeigt die nächste Portion des Zuordnungsstapels. Kein Nachladen — die
/// Ordner liegen seit dem Scan alle vor, sie werden nur portionsweise gezeigt.
final class ZeigeWeitereOrdnerEvent extends MandantenOverviewEvent {
  const ZeigeWeitereOrdnerEvent();
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

/// Ordnet einem bestehenden Mandanten einen noch nicht zugeordneten Ordner zu
/// — aus dem Zuordnungsstapel oder von der Mandantenkarte. War der Ordner als
/// „ohne Mandantenbezug" vermerkt, fällt der Vermerk weg.
final class VerknuepfeOrdnerEvent extends MandantenOverviewEvent {
  final int mandantId;
  final String ordnername;

  /// Nach gelungener Zuordnung die Fälle der Akte lesen — für die
  /// aufgeklappte Mandantenkarte, die ihre Fälle beim Aufklappen gelesen hat,
  /// die der neuen Akte aber nicht. Der Stapel braucht sie nicht, und je
  /// Zuordnung ein Blick ins Netzlaufwerk wäre dort nur Wartezeit.
  final bool faelleNachladen;

  const VerknuepfeOrdnerEvent({
    required this.mandantId,
    required this.ordnername,
    this.faelleNachladen = false,
  });

  @override
  List<Object> get props => [mandantId, ordnername, faelleNachladen];
}

/// Nimmt einem Mandanten einen Ordner wieder ab (#132). Der Ordner im
/// Dateisystem bleibt, er steht danach wieder im Zuordnungsstapel.
final class LoeseOrdnerEvent extends MandantenOverviewEvent {
  final int mandantId;
  final String ordnername;

  const LoeseOrdnerEvent({required this.mandantId, required this.ordnername});

  @override
  List<Object> get props => [mandantId, ordnername];
}

/// Lädt die Paket-Historie neu, nachdem
/// [ArbeitspaketGriff.schreibeUndVerbucheArbeitspaket] verbucht hat. Eigenes
/// Ereignis statt eines direkten `emit` im Mixin — siehe die Erklärung am
/// Kopf von `mandanten_overview_bloc.dart`. [abgeschlossen] lässt den
/// Aufrufer warten, bis die Historie im Zustand steht, statt fire-and-forget
/// zu bleiben.
final class HistorieNeuLadenEvent extends MandantenOverviewEvent {
  final Completer<void> abgeschlossen;

  const HistorieNeuLadenEvent(this.abgeschlossen);
}
