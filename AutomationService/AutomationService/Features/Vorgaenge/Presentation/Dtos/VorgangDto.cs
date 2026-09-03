using System.Text.Json;
using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Presentation.Dtos;

/// <summary>
/// Übertragungsformat eines Vorgangs. PascalCase wird als camelCase serialisiert
/// und passt 1:1 zur Flutter-Entität <c>Vorgang</c>. Die Antwortdaten werden als
/// opakes JSON (<see cref="Antwort"/>) verlustfrei durchgereicht — so muss das
/// Backend das ZentralrufReplyData-Schema nicht doppelt pflegen.
/// </summary>
public sealed record VorgangDto(
    string Referenz,
    DateTime AngefragtAm,
    string Status,
    string Rechtsgebiet,
    int? LaufendeNummer,
    string? Jahr,
    string? Abteilung,
    string? Kennzeichen,
    int? MandantId,
    string? MandantName,
    string? Gegner,
    string? UnfallDatum,
    string? GeschaedigtenKennzeichen,
    string? Unfallort,
    string? Unfalluhrzeit,
    string? PolizeiVorgangsnummer,
    JsonElement? Antwort,
    JsonElement? FeldWerte,
    JsonElement? Schadensaufstellung,
    JsonElement? Entwurf,
    int? SchreibenNummer,
    string? DokumentPfad,
    string? AktenOrdner,
    DateTime? AbgeschlossenAm)
{
    public static VorgangDto From(VorgangEntity e) => new(
        e.Referenz,
        e.AngefragtAm,
        e.Status,
        e.Rechtsgebiet,
        e.LaufendeNummer,
        e.Jahr,
        e.Abteilung,
        e.Kennzeichen,
        e.MandantId,
        e.MandantName,
        e.Gegner,
        e.UnfallDatum,
        e.GeschaedigtenKennzeichen,
        e.Unfallort,
        e.Unfalluhrzeit,
        e.PolizeiVorgangsnummer,
        ParseJson(e.AntwortJson),
        ParseJson(e.FeldWerteJson),
        ParseJson(e.SchadensaufstellungJson),
        ParseJson(e.EntwurfJson),
        e.SchreibenNummer,
        e.DokumentPfad,
        e.AktenOrdner,
        e.AbgeschlossenAm);

    public VorgangEntity ToEntity() => new()
    {
        Referenz = Referenz.Trim(),
        AngefragtAm = AngefragtAm,
        Status = Status,
        Rechtsgebiet = Rechtsgebiet,
        LaufendeNummer = LaufendeNummer,
        Jahr = Jahr,
        Abteilung = Abteilung,
        Kennzeichen = Kennzeichen,
        MandantId = MandantId,
        MandantName = MandantName,
        Gegner = Gegner,
        UnfallDatum = UnfallDatum,
        GeschaedigtenKennzeichen = GeschaedigtenKennzeichen,
        Unfallort = Unfallort,
        Unfalluhrzeit = Unfalluhrzeit,
        PolizeiVorgangsnummer = PolizeiVorgangsnummer,
        AntwortJson = Antwort.HasValue ? Antwort.Value.GetRawText() : null,
        FeldWerteJson = FeldWerte.HasValue ? FeldWerte.Value.GetRawText() : null,
        SchadensaufstellungJson =
            Schadensaufstellung.HasValue ? Schadensaufstellung.Value.GetRawText() : null,
        EntwurfJson = Entwurf.HasValue ? Entwurf.Value.GetRawText() : null,
        SchreibenNummer = SchreibenNummer,
        DokumentPfad = DokumentPfad,
        AktenOrdner = AktenOrdner,
        AbgeschlossenAm = AbgeschlossenAm,
    };

    static JsonElement? ParseJson(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.Clone();
        }
        catch
        {
            return null;
        }
    }
}
