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
mixin AktenzuordnungGriff
    on Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  UseCase<Mandant, VerknuepfeOrdnerParams> get _verknuepfeOrdner;
  UseCase<Mandant, LoeseOrdnerParams> get _loeseOrdner;
  UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> get _setzeOrdnerStatus;

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
        if (aktuell.ohneMandantenbezug.enthaelt(event.ordnername)) {
          await _vermerkZuruecknehmen(event.ordnername, emit);
        }
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

  /// Zuordnung sticht Vermerk — wie beim Import. Bliebe der Vermerk stehen,
  /// wäre der Ordner einem Mandanten zugeordnet **und** „ohne
  /// Mandantenbezug", und nach dem Lösen fiele er nicht in den Arbeitsvorrat
  /// zurück, sondern unter „Beiseitegelegt".
  ///
  /// Scheitert das, bleibt die Zuordnung trotzdem stehen: Sie ist gespeichert,
  /// und der Vermerk wirkt nicht, solange der Ordner zugeordnet ist.
  Future<void> _vermerkZuruecknehmen(
    String ordnername,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final result = await _setzeOrdnerStatus(
      SetzeOrdnerStatusParams(ordnernamen: [ordnername], art: null),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final stand):
        emit(aktuell.copyWith(ordnerStatus: stand));
    }
  }
}
