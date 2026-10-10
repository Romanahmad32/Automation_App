using AutomationService.Features.Vollmacht.Domain.Services;

namespace AutomationService.Features.Vollmacht.Presentation.Dtos;

/// <summary>
/// Antwort auf <c>POST api/Vollmacht/drucken|oeffnen</c>. <see cref="Status"/> ist
/// <c>gedruckt</c>, <c>druckFehlgeschlagen</c>, <c>ausgefuellt</c>,
/// <c>vorlageFehlt</c> oder <c>fehler</c>; <see cref="Pfad"/> ist die
/// ausgefüllte Datei, sofern sie zum Öffnen bereitliegt; <see cref="Drucker"/>
/// nennt bei <c>gedruckt</c> den Drucker, an den Word übergeben hat.
/// </summary>
public sealed record VollmachtErgebnisDto(
    string Status,
    string? Pfad,
    string? Meldung,
    IReadOnlyList<string> Warnungen,
    string? Drucker)
{
    public static VollmachtErgebnisDto From(VollmachtErgebnis ergebnis) => new(
        ergebnis.Art switch
        {
            VollmachtErgebnisArt.Gedruckt => "gedruckt",
            VollmachtErgebnisArt.DruckFehlgeschlagen => "druckFehlgeschlagen",
            VollmachtErgebnisArt.Ausgefuellt => "ausgefuellt",
            VollmachtErgebnisArt.VorlageFehlt => "vorlageFehlt",
            _ => "fehler",
        },
        ergebnis.Pfad,
        ergebnis.Meldung,
        ergebnis.Warnungen,
        ergebnis.Drucker);
}
