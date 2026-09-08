using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Presentation.Dtos;

/// <summary>
/// Eine gespeicherte Zeile der Registerhistorie, wie der Bearbeiten-Dialog sie
/// zurückbekommt.
///
/// <c>Freitext</c> geht mit hinaus: Er ist der Beleg, gegen den der Anwalt eine
/// Berichtigung liest. <c>Kennung</c> ebenso — sie ist die stabile Referenz
/// (§7.2), während <c>Id</c> eine Zählnummer der Datenbank bleibt.
/// </summary>
public sealed record RegisterHistorieZeileDto(
    int Id,
    string Kennung,
    int Jahr,
    int LaufendeNummer,
    string NummerZusatz,
    string Aktenzeichen,
    string Abteilung,
    string Sachart,
    string Mandant,
    string Gegner,
    string Sachbestand,
    string Unfalldatum,
    string Rechtsgebiet,
    string Freitext,
    string Sicherheit,
    IReadOnlyList<string> Befunde,
    IReadOnlyList<string> Hinweise,
    int? MandantId,
    DateTime? GeaendertAm)
{
    public static RegisterHistorieZeileDto From(RegisterHistorieEntity zeile)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        return new RegisterHistorieZeileDto(
            zeile.Id,
            zeile.Kennung,
            zeile.Jahr,
            zeile.LaufendeNummer,
            zeile.NummerZusatz,
            zeile.Aktenzeichen,
            zeile.Abteilung,
            zeile.Sachart,
            zeile.Mandant,
            zeile.Gegner,
            zeile.Sachbestand,
            zeile.Unfalldatum,
            zeile.Rechtsgebiet,
            zeile.Freitext,
            zeile.Sicherheit,
            RegisterHistorieListen.Lies(zeile.BefundeJson),
            RegisterHistorieListen.Lies(zeile.HinweiseJson),
            zeile.MandantId,
            zeile.GeaendertAm);
    }
}

/// <summary>
/// Die Berichtigung einer historischen Zeile. Alles nullable und leer als
/// gültiger Wert: Ein Feld zu <em>leeren</em> ist eine gewollte Änderung — im
/// Bestand steht manches, was gar nicht in die Spalte gehört.
///
/// Jahr und laufende Nummer stehen bewusst nicht darin (siehe
/// <see cref="RegisterHistorieAenderung"/>).
/// </summary>
public sealed record RegisterHistorieAenderungDto(
    string? Abteilung,
    string? Sachart,
    string? Mandant,
    string? Gegner,
    string? Sachbestand,
    string? Unfalldatum,
    string? Rechtsgebiet)
{
    public RegisterHistorieAenderung ZuDomaene() => new(
        Abteilung ?? string.Empty,
        Sachart ?? string.Empty,
        Mandant ?? string.Empty,
        Gegner ?? string.Empty,
        Sachbestand ?? string.Empty,
        Unfalldatum ?? string.Empty,
        Rechtsgebiet ?? string.Empty);
}
