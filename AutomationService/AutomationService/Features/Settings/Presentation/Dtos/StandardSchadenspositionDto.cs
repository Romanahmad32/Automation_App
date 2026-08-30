using AutomationService.Features.Settings.Domain.Persistence;

namespace AutomationService.Features.Settings.Presentation.Dtos;

/// <summary>
/// Übertragungsformat einer Standardposition der Schadensaufstellung (§4.4).
/// Die Reihenfolge steckt in der Reihenfolge der Liste, nicht in einem Feld —
/// beide Seiten arbeiten ohnehin nur mit der kompletten Liste.
/// </summary>
public sealed record StandardSchadenspositionDto(string Bezeichnung, decimal? Betrag)
{
    public static StandardSchadenspositionDto From(StandardSchadenspositionEntity e) =>
        new(e.Bezeichnung, e.Betrag);

    public StandardSchadenspositionEntity ToEntity() => new()
    {
        Bezeichnung = Bezeichnung,
        Betrag = Betrag,
    };
}
