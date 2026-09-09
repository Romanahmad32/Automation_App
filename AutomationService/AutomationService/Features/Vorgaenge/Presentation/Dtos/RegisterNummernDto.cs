using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Presentation.Dtos;

/// <summary>
/// Der Nummernstand eines Jahrgangs (§6.3) für den Vertrag: der Vorschlag für
/// die nächste laufende Nummer und die im Jahrgang schon belegten.
/// </summary>
public sealed record RegisterNummernDto(
    string Jahr,
    int HoechsteNummer,
    int NaechsteNummer,
    IReadOnlyList<int> Belegte)
{
    public static RegisterNummernDto From(RegisterNummernStand stand)
    {
        ArgumentNullException.ThrowIfNull(stand);
        return new RegisterNummernDto(stand.Jahr, stand.HoechsteNummer, stand.NaechsteNummer, stand.Belegte);
    }
}
