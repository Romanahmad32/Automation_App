using AutomationService.Features.Vollmacht.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>
/// Antwort auf <c>POST api/Vollmacht/vorschau</c>. <see cref="Status"/> ist
/// <c>erstellt</c>, <c>vorlageFehlt</c> oder <c>fehler</c>; <see cref="Pdf"/>
/// trägt die Seite (Base64), nur bei <c>erstellt</c>.
/// </summary>
public sealed record VollmachtVorschauDto(
    string Status,
    string? Meldung,
    IReadOnlyList<string> Warnungen,
    byte[]? Pdf)
{
    public static VollmachtVorschauDto From(VollmachtVorschau vorschau) => new(
        vorschau.Art switch
        {
            VollmachtVorschauArt.Erstellt => "erstellt",
            VollmachtVorschauArt.VorlageFehlt => "vorlageFehlt",
            _ => "fehler",
        },
        vorschau.Meldung,
        vorschau.Warnungen,
        vorschau.Pdf);
}
