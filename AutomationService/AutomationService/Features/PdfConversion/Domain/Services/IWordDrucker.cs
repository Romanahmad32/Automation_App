namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Schickt ein fertiges Word-Dokument an den Windows-Standarddrucker — über
/// das installierte Word, damit das Papier aussieht wie die Datei (§4.11).
///
/// Hier und nicht im Schnitt, der druckt: Word-COM ist nicht threadsafe, und
/// die PDF-Erzeugung hält ihre Word-Instanz schon auf einem eigenen
/// STA-Thread vorgewärmt (<see cref="WordInteropPdfConversionService"/>). Ein
/// zweiter Thread mit einer zweiten Instanz kostete beim ersten Druck die
/// Startzeit von Word — genau in dem Moment, in dem der Mandant im Büro
/// wartet. Hinter einer Schnittstelle, damit die Tests ohne Word laufen.
/// </summary>
public interface IWordDrucker
{
    /// <summary>
    /// Druckt <paramref name="docxPfad"/> und kehrt erst zurück, wenn Word den
    /// Auftrag an die Druckwarteschlange übergeben hat. Wirft, wenn Word fehlt
    /// oder der Druck scheitert — der Aufrufer fällt dann auf „in Word öffnen"
    /// zurück.
    /// </summary>
    Task DruckeAsync(string docxPfad, CancellationToken cancellationToken = default);
}
