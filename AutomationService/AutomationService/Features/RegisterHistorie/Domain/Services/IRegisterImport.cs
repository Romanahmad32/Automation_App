namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Übernimmt das gewachsene Kanzleiregister ab 2018 in Jahrgängen (§6.2).
///
/// Der Anlass: rund 90 Seiten Word mit Tausenden Zeilen passen in keine Sitzung
/// eines Erzeugers — er bricht ab oder wird gegen Ende ungenau, und die Datei
/// sieht trotzdem vollständig aus. Deshalb wird jahrgangsweise eingelesen und
/// jeder Jahrgang für sich geprüft: rund 200 Zeilen sind eine prüfbare Menge.
/// </summary>
public interface IRegisterImport
{
    /// <summary>
    /// Führt den Auftrag aus. Bei <c>NurPruefen</c> wird nichts geschrieben,
    /// der Bericht ist derselbe. Das Schreiben läuft in einer Transaktion:
    /// entweder die ganze Datei oder nichts.
    /// </summary>
    Task<RegisterImportBefund> FuehreAusAsync(
        RegisterImportAuftrag auftrag,
        CancellationToken cancellationToken = default);
}
