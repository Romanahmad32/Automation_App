using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Presentation.Dtos;

/// <summary>
/// Die Zeilen der Registeransicht (§6.2). Ein Umschlag statt einer blanken
/// Liste, damit später eine Gesamtzahl oder ein Stand danebentreten kann, ohne
/// dass der Vertrag seine Form ändert.
/// </summary>
public sealed record RegisterZeilenDto(IReadOnlyList<RegisterZeileDto> Zeilen)
{
    public static RegisterZeilenDto From(IEnumerable<RegisterZeile> zeilen)
    {
        ArgumentNullException.ThrowIfNull(zeilen);
        return new RegisterZeilenDto([.. zeilen.Select(RegisterZeileDto.From)]);
    }
}

/// <summary>
/// Eine Zeile im verbindlichen Spaltenschema, gleich welcher Herkunft.
/// <c>Quelle</c> sagt, welcher: Eine historische Zeile lässt sich nicht öffnen,
/// sondern nur berichtigen, und trägt dafür <c>HistorieId</c> statt
/// <c>VorgangReferenz</c>.
/// </summary>
public sealed record RegisterZeileDto(
    string Jahr,
    int? LaufendeNummer,
    string Zeichen,
    string Parteien,
    string Sachbestand,
    string Rechtsgebiet,
    bool Abgeschlossen,
    string Quelle,
    int? HistorieId,
    string? VorgangReferenz,
    string Sicherheit,
    IReadOnlyList<string> Befunde)
{
    public static RegisterZeileDto From(RegisterZeile zeile)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        return new RegisterZeileDto(
            zeile.Jahr,
            zeile.LaufendeNummer,
            zeile.Zeichen,
            zeile.Parteien,
            zeile.Sachbestand,
            zeile.Rechtsgebiet,
            zeile.Abgeschlossen,
            zeile.Quelle,
            zeile.HistorieId,
            zeile.VorgangReferenz,
            zeile.Sicherheit,
            zeile.Befunde ?? []);
    }
}
