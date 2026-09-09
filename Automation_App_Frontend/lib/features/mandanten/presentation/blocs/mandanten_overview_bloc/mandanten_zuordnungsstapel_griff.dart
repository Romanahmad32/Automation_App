part of 'mandanten_overview_bloc.dart';

/// Die Ereignisbehandlungen des Zuordnungsstapels: der Vermerk „ohne
/// Mandantenbezug", die drei Filterachsen und der gezeigte Ausschnitt.
///
/// Eigene Datei aus demselben Grund wie [ArbeitspaketGriff] — der Bloc hatte
/// die Grenze von 250 Anweisungszeilen erreicht. Der Schnitt liegt am
/// Fachthema: Diese drei Behandlungen arbeiten alle am Stapel und an keinem
/// Abruf beim Dienst außer dem einen, der den Vermerk schreibt. Anders als
/// dort emittieren sie direkt — über den von `on<...>` gereichten [Emitter],
/// nicht über `Bloc.emit`, das im Mixin nicht zur Verfügung steht (die
/// Begründung steht am Kopf von `mandanten_overview_bloc.dart`).
mixin ZuordnungsstapelGriff
    on Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  UseCase<List<OrdnerStatus>, SetzeOrdnerStatusParams> get _setzeOrdnerStatus;

  Future<void> _onSetzeOrdnerStatus(
    SetzeOrdnerStatusEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    if (event.ordnernamen.isEmpty) return;
    final result = await _setzeOrdnerStatus(
      SetzeOrdnerStatusParams(ordnernamen: event.ordnernamen, art: event.art),
    );
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) return;
    switch (result) {
      case Left(value: final failure):
        // Nur eine Meldung, nicht die Seite: den Scan über tausende Ordner,
        // Filter und Scrollstand für eine gescheiterte Aktion wegzuwerfen wäre
        // teurer als die Aktion selbst.
        emit(aktuell.copyWith(fehler: failure.message));
      case Right(value: final stand):
        emit(aktuell.copyWith(ordnerStatus: stand, fehlerVerwerfen: true));
    }
  }

  void _onSetzeFilter(
    SetzeZuordnungFilterEvent event,
    Emitter<MandantenOverviewState> emit,
  ) {
    final current = state;
    if (current is MandantenOverviewLoaded) {
      // Grenze zurück auf die erste Portion: Wer im vorigen Topf bis Ordner
      // 400 gescrollt hat, bekäme sonst im nächsten sofort 400 Zeilen.
      emit(
        current.copyWith(
          zuordnungFilter: event.filter,
          sichtbareOrdnerGrenze: MandantenOverviewBloc.ordnerPortion,
        ),
      );
    }
  }

  /// Die nächste Portion des Zuordnungsstapels zeigen. Am Ende angekommen
  /// passiert nichts — der Scroll meldet sich Pixel für Pixel, und jede
  /// Erhöhung ohne neue Zeilen wäre ein Rebuild für nichts.
  void _onZeigeWeitereOrdner(
    ZeigeWeitereOrdnerEvent event,
    Emitter<MandantenOverviewState> emit,
  ) {
    final current = state;
    if (current is MandantenOverviewLoaded && current.gibtWeitereOrdner) {
      emit(
        current.copyWith(
          sichtbareOrdnerGrenze:
              current.sichtbareOrdnerGrenze +
              MandantenOverviewBloc.ordnerPortion,
        ),
      );
    }
  }
}
