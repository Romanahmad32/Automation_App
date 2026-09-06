part of 'mandanten_overview_bloc.dart';

/// Baut, schreibt und verbucht ein Arbeitspaket für den KI-Agenten (Issue
/// #108, „Der Weg des Anwalts"): eigene Datei, damit die Reihenfolge — bauen,
/// speichern lassen, **erst dann** verbuchen — an einer Stelle steht, statt
/// zwischen den übrigen Ereignisbehandlungen des Blocs zu verschwinden. Bricht
/// der Anwalt den Speichern-Dialog ab, ruft der Aufrufer [schreibeUndVerbuche]
/// gar nicht erst auf — deshalb ist das kein Ereignis mit `emit`, sondern ein
/// Baustein, den der Bloc aus einer öffentlichen Methode heraus benutzt.
class MandantenArbeitspaketAbruf {
  final UseCase<List<Mandant>, NoParams> getMandanten;
  final UseCase<KanzleiSettings, NoParams> getKanzleiSettings;
  final UseCase<List<ImportPaket>, NoParams> getImportPakete;
  final UseCase<ImportPaket, NotiereImportPaketParams> notiereImportPaket;
  final UseCase<void, SchreibeArbeitspaketParams> schreibeArbeitspaket;

  const MandantenArbeitspaketAbruf({
    required this.getMandanten,
    required this.getKanzleiSettings,
    required this.getImportPakete,
    required this.notiereImportPaket,
    required this.schreibeArbeitspaket,
  });

  /// Das komplette Register — für den Namensvorschlag im Paket und für
  /// „Sichere Treffer". [MandantenOverviewLoaded.mandanten] ist nur ein
  /// Ausschnitt (seitenweises Laden), hier zählt der ganze Bestand.
  Future<List<Mandant>> alleMandanten() async {
    final result = await getMandanten(const NoParams());
    return switch (result) {
      Right(value: final m) => m,
      Left() => const <Mandant>[],
    };
  }

  /// Baut das nächste Arbeitspaket aus den offenen Ordnern von [stand]. Reine
  /// Berechnung — schreibt und verbucht nichts.
  Future<Arbeitspaket> baue(MandantenOverviewLoaded stand, int anzahl) async {
    final mandanten = await alleMandanten();
    final settingsResult = await getKanzleiSettings(const NoParams());
    final stammordner = switch (settingsResult) {
      Right(value: final s) => s.aktenStammordner,
      Left() => '',
    };
    final pakete = await _historie(stand);
    // Vergibt keine Nummer: das tut das Backend beim Verbuchen. Diese Zahl
    // ist nur der Vorschlag für die Datei und die Rückmeldung — korrigiert
    // wird sie nach dem Verbuchen nicht, dafür wird die Historie neu geholt.
    final naechsteNummer = pakete.isEmpty
        ? 1
        : pakete.map((p) => p.nummer).reduce((a, b) => a > b ? a : b) + 1;

    // Derselbe Vorfilter wie in `ImportAehnlichkeit`/`SichereTreffer`: einmal
    // gebaut, statt je Ordner gegen den vollen Bestand zu suchen — sonst
    // wäre das O(Ordner × Mandanten), und bei rund 4000 Ordnern und ebenso
    // vielen Mandanten genau die Stelle, die weh tut. Der Index schließt
    // nichts aus, was `MandantErkennung.finde` gefunden hätte.
    final index = MandantenNamensindex(mandanten);
    return ArbeitspaketBauen.baue(
      offeneOrdner: [
        for (final akte in stand.offeneOrdnerFuerPaket)
          _alsArbeitspaketOrdner(akte, index),
      ],
      bekannteMandanten: [for (final m in mandanten) BekannterMandant.aus(m)],
      paketNummer: naechsteNummer,
      stammordner: stammordner,
      anleitung: ImportAnleitung.paketText,
      erstelltAm: DateTime.now(),
      anzahl: anzahl,
    );
  }

  /// Schreibt [paket] nach [pfad], legt die Anleitung in die Zwischenablage
  /// und verbucht das Paket erst danach.
  Future<Either<Failure, ImportPaket>> schreibeUndVerbuche({
    required Arbeitspaket paket,
    required String pfad,
  }) async {
    final geschrieben = await schreibeArbeitspaket(
      SchreibeArbeitspaketParams(paket: paket, pfad: pfad),
    );
    if (geschrieben case Left(value: final failure)) return Left(failure);

    // Die Anleitung landet erst nach erfolgreichem Schreiben in der
    // Zwischenablage — sonst läge dort eine Anleitung zu einer Datei, die es
    // gar nicht gibt.
    await Clipboard.setData(ClipboardData(text: ImportAnleitung.paketText));

    return notiereImportPaket(
      NotiereImportPaketParams(ordnernamen: paket.ordnernamen),
    );
  }

  /// Die Paket-Historie frisch geholt — nach dem Verbuchen wird sie neu
  /// gelesen statt die Paketnummer lokal nachzukorrigieren.
  Future<List<ImportPaket>> historieNeuLaden() async {
    final result = await getImportPakete(const NoParams());
    return switch (result) {
      Right(value: final p) => p,
      Left() => const <ImportPaket>[],
    };
  }

  Future<List<ImportPaket>> _historie(MandantenOverviewLoaded stand) async {
    final result = await getImportPakete(const NoParams());
    return switch (result) {
      Right(value: final p) => p,
      Left() => stand.importPakete,
    };
  }

  /// Aktentyp und Namensvorschlag rechnet der Aufrufer aus — dieselbe
  /// Arbeitsteilung wie in `ArbeitspaketBauen`: die Domain kennt
  /// `nameVorschlagAusOrdner` nicht, die eine Präfixtabelle bleibt trotzdem
  /// die eine.
  ///
  /// [index] grenzt den Bestand vor `MandantErkennung.finde` auf die
  /// wenigen Kandidaten ein, die überhaupt zum Nachnamen passen können.
  ArbeitspaketOrdner _alsArbeitspaketOrdner(
    Akte akte,
    MandantenNamensindex index,
  ) {
    final vorschlag = nameVorschlagAusOrdner(akte.ordnername);
    final kandidaten = index.kandidaten(nachname: vorschlag.nachname);
    final treffer = MandantErkennung.finde(
      mandanten: kandidaten,
      vorname: vorschlag.vorname,
      nachname: vorschlag.nachname,
    );
    final erster = treffer.isEmpty ? null : treffer.first;
    return ArbeitspaketOrdner(
      ordnername: akte.ordnername,
      aktentyp: akte.aktentyp,
      nameVorschlagVorname: vorschlag.vorname,
      nameVorschlagNachname: vorschlag.nachname,
      bekannterMandant: erster?.mandant.anzeigename,
      begruendung: erster?.begruendung,
    );
  }
}
