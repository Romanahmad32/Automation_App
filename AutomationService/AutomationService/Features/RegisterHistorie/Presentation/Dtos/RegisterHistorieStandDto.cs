using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Presentation.Dtos;

/// <summary>
/// Der Stand der Übernahme, wie ihn die Registeransicht als Chip-Zeile zeigt
/// (§6.2): je Jahrgang ein Häkchen, ein „fehlt" oder die Zahl der offenen
/// Lücken.
/// </summary>
public sealed record RegisterHistorieStandDto(
    IReadOnlyList<JahrgangStandDto> Jahrgaenge,
    IReadOnlyList<int> FehlendeJahrgaenge)
{
    public static RegisterHistorieStandDto From(RegisterHistorieStand stand)
    {
        ArgumentNullException.ThrowIfNull(stand);
        return new RegisterHistorieStandDto(
            [.. stand.Jahrgaenge.Select(JahrgangStandDto.From)],
            stand.FehlendeJahrgaenge);
    }
}

/// <summary>Ein übernommener Jahrgang mit seinen offenen Punkten.</summary>
public sealed record JahrgangStandDto(
    int Jahrgang,
    int Zeilen,
    int HoechsteNummer,
    IReadOnlyList<int> Luecken,
    int MitBefund,
    DateTime ZuletztImportiertAm)
{
    public static JahrgangStandDto From(JahrgangStand stand)
    {
        ArgumentNullException.ThrowIfNull(stand);
        return new JahrgangStandDto(
            stand.Jahrgang,
            stand.Zeilen,
            stand.HoechsteNummer,
            stand.Luecken,
            stand.MitBefund,
            stand.ZuletztImportiertAm);
    }
}
