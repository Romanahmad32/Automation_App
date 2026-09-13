part of 'mandanten_overview_bloc.dart';

/// Die Ereignisbehandlungen, die einen Ordner einem Mandanten geben oder
/// wieder nehmen — aus dem Zuordnungsstapel und von der Mandantenkarte (#132).
///
/// Eigene Datei aus demselben Grund wie [ZuordnungsstapelGriff]: Der Bloc
/// stand an der Grenze von 250 Anweisungszeilen. Wie dort emittieren die
/// Behandlungen über den von `on<...>` gereichten [Emitter] (Begründung am
/// Kopf von `mandanten_overview_bloc.dart`).
///
/// Beide schreiben den Zustand fort und scannen **nicht** neu — der Ordner
/// wechselt zwischen Karte und Stapel, weil `zugeordneteOrdnernamen` sich
/// ändert (`FALLSTRICKE.md`: „Kein Rescan nach einer Änderung am Register").
///
/// Den Vermerk „ohne Mandantenbezug" nimmt der Dienst mit der Zuordnung
/// zurück, hier wird er nur aus dem Zustand gestrichen
/// ([MandantenOverviewLoaded.mitZuordnung]). Das Frontend dafür selbst
/// anzusprechen ließe die übrigen Wege zu einer Zuordnung — Ablage, neuer
/// Mandant mit vorbelegtem Ordner — ohne die Regel.
mixin AktenzuordnungGriff
    on Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  UseCase<Mandant, VerknuepfeOrdnerParams> get _verknuepfeOrdner;
  UseCase<Mandant, LoeseOrdnerParams> get _loeseOrdner;

  Future<void> _onVerknuepfe(
    VerknuepfeOrdnerEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _verknuepfeOrdner(
      VerknuepfeOrdnerParams(
        mandantId: event.mandantId,
        ordnername: event.ordnername,
      ),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        // Auch das 409 für einen schon vergebenen Ordner landet hier: Die
        // Meldung des Dienstes nennt den Besitzer.
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final aktualisiert):
        emit(aktuell.mitZuordnung(aktualisiert, event.ordnername));
        if (event.faelleNachladen) _ladeFaelleVon(aktuell, event.ordnername);
    }
  }

  Future<void> _onLoese(
    LoeseOrdnerEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _loeseOrdner(
      LoeseOrdnerParams(
        mandantId: event.mandantId,
        ordnername: event.ordnername,
      ),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final aktualisiert):
        emit(aktuell.mitGeloesterZuordnung(aktualisiert, event.ordnername));
    }
  }

  /// Erst nach gelungener Zuordnung: Bei einem 409 gehört die Akte jemand
  /// anderem, und ihre Fälle auf einem womöglich langsamen Netzlaufwerk zu
  /// lesen wäre Arbeit für eine Karte, an der sie gar nicht erscheint.
  void _ladeFaelleVon(MandantenOverviewLoaded stand, String ordnername) {
    final gemeint = OrdnernamenMenge([ordnername]);
    for (final akte in stand.akten) {
      if (gemeint.enthaelt(akte.ordnername)) add(LadeFaelleEvent(akte));
    }
  }
}
