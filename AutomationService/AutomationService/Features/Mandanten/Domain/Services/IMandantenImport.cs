namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Übernimmt ein maschinell erzeugtes Abbild des Aktenbestands ins Register
/// (§5.1/§6.1). Der Anlass: rund 4000 Ordner einzeln von Hand zuzuordnen ist
/// nicht leistbar — die Zuordnung entsteht außerhalb der App als Datei und
/// wird hier geprüft, gezeigt und erst nach Freigabe geschrieben.
/// </summary>
public interface IMandantenImport
{
    /// <summary>
    /// Führt den Auftrag aus. Bei <c>NurPruefen</c> wird nichts geschrieben,
    /// der Bericht ist derselbe. Das Schreiben läuft in einer Transaktion:
    /// entweder die ganze Datei oder nichts.
    /// </summary>
    Task<MandantenImportBefund> FuehreAusAsync(
        MandantenImportAuftrag auftrag,
        CancellationToken cancellationToken = default);
}
