part of 'mandanten_overview_bloc.dart';

/// Was der Bloc für „Arbeitspaket holen" und „Sichere Treffer übernehmen"
/// (Issue #108) nach außen zeigt: das ganze Register lesen, ein Paket bauen,
/// es schreiben und verbuchen.
///
/// Eigene Datei aus demselben Grund wie [MandantenStandAbruf] und
/// [MandantenArbeitspaketAbruf] — nur dass diese drei Methoden anders als
/// jene beiden Bausteine nicht als reine Berechnung auskommen:
/// [baueArbeitspaket] liest `state`, [schreibeUndVerbucheArbeitspaket]
/// aktualisiert danach den Zustand mit frischer Paket-Historie. Anders als
/// `VersandGriff`/`AnredeGriff` im `EmailEntwurfCubit` geschieht das aber
/// **nicht** über einen direkten `emit`-Aufruf im Mixin — die Begründung
/// steht am Kopf von `mandanten_overview_bloc.dart`. Stattdessen löst
/// [schreibeUndVerbucheArbeitspaket] [HistorieNeuLadenEvent] aus, dessen
/// Behandlung ([_onHistorieNeuLaden]) über den von `on<...>` gereichten
/// [Emitter] emittiert; ein [Completer] lässt den Aufrufer darauf warten.
mixin ArbeitspaketGriff
    on Bloc<MandantenOverviewEvent, MandantenOverviewState> {
  MandantenArbeitspaketAbruf get _arbeitspaket;

  /// Das komplette Mandantenregister — für „Sichere Treffer" (Issue #108).
  /// [MandantenOverviewLoaded.mandanten] ist nur ein Ausschnitt (seitenweises
  /// Laden), hier zählt der ganze Bestand.
  Future<List<Mandant>> ladeAlleMandanten() => _arbeitspaket.alleMandanten();

  /// Baut das nächste Arbeitspaket aus den offenen Ordnern — reine
  /// Berechnung, schreibt und verbucht nichts. [anzahl] zählt **Mandanten**
  /// (`ArbeitspaketBauen.vorgabeAnzahl`), nicht Ordner.
  Future<Arbeitspaket> baueArbeitspaket(int anzahl) async {
    final aktuell = state;
    if (aktuell is! MandantenOverviewLoaded) {
      return Arbeitspaket(paket: 0, erstelltAm: DateTime.now());
    }
    return _arbeitspaket.baue(aktuell, anzahl);
  }

  /// Schreibt [paket] nach [pfad], legt die Anleitung in die Zwischenablage
  /// und verbucht das Paket erst danach — und aktualisiert die Paket-Historie
  /// im Zustand. **Nur aufrufen, nachdem der Speichern-Dialog erfolgreich
  /// war**: bricht der Anwalt ihn ab, darf nichts verbucht werden.
  Future<Either<Failure, ImportPaket>> schreibeUndVerbucheArbeitspaket({
    required Arbeitspaket paket,
    required String pfad,
  }) async {
    final ergebnis = await _arbeitspaket.schreibeUndVerbuche(
      paket: paket,
      pfad: pfad,
    );
    if (ergebnis case Right()) {
      final abgeschlossen = Completer<void>();
      add(HistorieNeuLadenEvent(abgeschlossen));
      await abgeschlossen.future;
    }
    return ergebnis;
  }

  /// Nimmt ein versehentlich herausgegebenes, noch offenes Paket zurück und
  /// lädt danach die Historie neu — dieselbe Reihenfolge wie bei
  /// [schreibeUndVerbucheArbeitspaket].
  Future<Either<Failure, void>> loescheImportPaket(int nummer) async {
    final ergebnis = await _arbeitspaket.loesche(nummer);
    if (ergebnis case Right()) {
      final abgeschlossen = Completer<void>();
      add(HistorieNeuLadenEvent(abgeschlossen));
      await abgeschlossen.future;
    }
    return ergebnis;
  }

  /// Lädt die Paket-Historie neu und schreibt sie in den Zustand — als
  /// Ereignisbehandlung, weil `Bloc.emit` (anders als `Cubit`s `emit`) nur
  /// `@visibleForTesting` trägt und sich deshalb aus keinem Mixin heraus
  /// direkt aufrufen lässt. [HistorieNeuLadenEvent.abgeschlossen] wird immer
  /// abgeschlossen, auch wenn der Zustand inzwischen kein
  /// [MandantenOverviewLoaded] mehr ist — sonst hinge
  /// [schreibeUndVerbucheArbeitspaket] auf immer.
  Future<void> _onHistorieNeuLaden(
    HistorieNeuLadenEvent event,
    Emitter<MandantenOverviewState> emit,
  ) async {
    final historie = await _arbeitspaket.historieNeuLaden();
    final aktuell = state;
    if (aktuell is MandantenOverviewLoaded) {
      emit(aktuell.copyWith(importPakete: historie));
    }
    event.abgeschlossen.complete();
  }
}
