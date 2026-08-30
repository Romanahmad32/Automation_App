part of 'mandanten_overview_bloc.dart';

/// Trägt zusammen, was die Mandantenseite zum Anzeigen braucht: eine Seite des
/// Registers, die Namen aller zugeordneten Akten-Ordner, die Vermerke und den
/// Akten-Scan.
///
/// Vier Abrufe — und für jeden gilt etwas anderes, wenn er fehlschlägt. Das
/// zusammen mit den Ereignisbehandlungen in einer Datei zu halten hieße, beim
/// Lesen des Blocs jedes Mal durch diese Regeln zu waten.
class MandantenStandAbruf {
  final UseCase<MandantenSeite, MandantenSeiteParams> getSeite;
  final UseCase<List<String>, NoParams> getAktenOrdnernamen;
  final UseCase<List<OrdnerStatus>, NoParams> getOrdnerStatus;
  final UseCase<List<Akte>, NoParams> getAkten;

  const MandantenStandAbruf({
    required this.getSeite,
    required this.getAktenOrdnernamen,
    required this.getOrdnerStatus,
    required this.getAkten,
  });

  /// Eine Seite des Registers — für Suche und Nachladen.
  Future<Either<Failure, MandantenSeite>> seite({
    String suche = '',
    int ueberspringen = 0,
    int anzahl = 0,
  }) => getSeite(
    MandantenSeiteParams(
      suche: suche,
      ueberspringen: ueberspringen,
      anzahl: anzahl,
    ),
  );

  /// Der vollständige Stand der Seite. [alt] ist der bisherige Stand, sofern es
  /// einen gibt: Er liefert Suchbegriff und Filter und ist der Rückfall für
  /// die Abrufe, die scheitern dürfen. [nurRegister] lässt den teuren
  /// Akten-Scan stehen — bei einem neuen oder bearbeiteten Mandanten hat sich
  /// am Dateisystem nichts geändert.
  Future<Either<Failure, MandantenOverviewLoaded>> lade({
    MandantenOverviewLoaded? alt,
    bool nurRegister = false,
  }) async {
    // So viele Mandanten holen, wie schon geladen waren — sonst schrumpfte die
    // Liste beim Neuladen unter dem Anwender auf die erste Seite zusammen.
    final geladen = alt?.mandanten.length ?? 0;
    final seiteResult = await seite(
      suche: alt?.query ?? '',
      anzahl: geladen > MandantenOverviewBloc.seitenGroesse
          ? geladen
          : MandantenOverviewBloc.seitenGroesse,
    );
    final MandantenSeite gefunden;
    switch (seiteResult) {
      case Right(value: final s):
        gefunden = s;
      case Left(value: final failure):
        return Left(failure);
    }

    // Die zugeordneten Ordner sind die Trennlinie des Zuordnungsstapels — ohne
    // sie stünden zugeordnete Ordner darin als offen. Ein Fehlschlag ist hier
    // deshalb keine Kleinigkeit, die sich still übergehen ließe; nur ein
    // bisheriger Stand darf einspringen.
    final ordnerResult = await getAktenOrdnernamen(const NoParams());
    final List<String> zugeordnet;
    switch (ordnerResult) {
      case Right(value: final namen):
        zugeordnet = namen;
      case Left(value: final failure):
        if (alt == null) return Left(failure);
        zugeordnet = alt.zugeordneteOrdnernamen;
    }

    // Die Vermerke liegen in derselben Datenbank wie das Register und kosten
    // einen Abruf — sie kommen deshalb auch beim reinen Registerlauf mit.
    // Scheitert er, bleibt der bisherige Stand stehen: ein verlorener Vermerk
    // würde einen entschiedenen Ordner still zurück in den Stapel werfen.
    final statusResult = await getOrdnerStatus(const NoParams());
    final vermerke = switch (statusResult) {
      Right(value: final s) => s,
      Left() => alt?.ordnerStatus ?? const <OrdnerStatus>[],
    };

    if (nurRegister && alt != null) {
      return Right(
        alt.mitSeite(gefunden, zugeordnet).copyWith(ordnerStatus: vermerke),
      );
    }

    // Der Akten-Scan darf fehlschlagen (z. B. kein Stammordner) ohne die ganze
    // Seite zu blockieren — dann werden nur keine Akten angezeigt.
    final aktenResult = await getAkten(const NoParams());
    final akten = switch (aktenResult) {
      Right(value: final a) => a,
      Left() => const <Akte>[],
    };

    return Right(
      MandantenOverviewLoaded(
        mandanten: gefunden.mandanten,
        gesamtMandanten: gefunden.gesamt,
        gefundeneMandanten: gefunden.gefiltert,
        zugeordneteOrdnernamen: zugeordnet,
        akten: akten,
        ordnerStatus: vermerke,
        query: alt?.query ?? '',
        zuordnungFilter: alt?.zuordnungFilter ?? const ZuordnungFilter(),
      ),
    );
  }
}
