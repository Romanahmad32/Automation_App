using AutomationService.Features.Mandanten.Domain.Services;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Eine Importdatei. Der Rumpf der Anfrage ist Zeichen für Zeichen die Datei,
/// die außerhalb der App entsteht — kein Umschlag, keine zusätzlichen Felder.
/// Nur deshalb kann derselbe Inhalt geprüft, übernommen und aufgehoben werden,
/// ohne dass jemand ihn dazwischen umformt.
///
/// <c>Version</c> ist die Format-Fassung, derzeit 1; fehlt sie, wird 1
/// angenommen, eine andere wird abgelehnt statt halb gelesen.
/// <c>OhneMandantenbezug</c> sind Ordner, die der Erzeuger als „gehört keinem
/// Mandanten" erkannt hat (Buchhaltung, Vorlagen, Ablagen). Sie landen als
/// Vermerk in <c>OrdnerStatus</c> und verlassen damit den Zuordnungsstapel,
/// ohne dass jemand sie einzeln durchsehen muss.
/// </summary>
public sealed record MandantenImportDto(
    int? Version,
    IReadOnlyList<ImportMandantDto>? Mandanten,
    IReadOnlyList<string>? OhneMandantenbezug);

/// <summary>
/// Ein Mandant in der Importdatei. Alles ist freiwillig außer dem Namen: was im
/// Aktenbestand nicht auffindbar war, bleibt leer, statt geraten zu werden.
/// </summary>
public sealed record ImportMandantDto(
    string? Anrede,
    string? Vorname,
    string? Nachname,
    string? StrasseHausnummer,
    string? Postleitzahl,
    string? Ort,
    string? EmailAdresse,
    string? Telefonnummer,
    string? Notiz,
    IReadOnlyList<string>? AktenOrdnernamen,
    IReadOnlyList<string>? Kennzeichen,
    string? Quelle,
    string? Sicherheit)
{
    public ImportMandant ZuDomaene() => new(
        Anrede ?? string.Empty,
        Vorname ?? string.Empty,
        Nachname ?? string.Empty,
        StrasseHausnummer ?? string.Empty,
        Postleitzahl ?? string.Empty,
        Ort ?? string.Empty,
        EmailAdresse ?? string.Empty,
        Telefonnummer ?? string.Empty,
        Notiz ?? string.Empty,
        AktenOrdnernamen ?? [],
        Kennzeichen ?? [],
        Quelle ?? string.Empty,
        Sicherheit ?? string.Empty);
}
