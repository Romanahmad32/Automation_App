using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>Wo der Entwurf geöffnet wurde (REQUIREMENTS.md §4.7).</summary>
/// <param name="Weg">"outlook" oder "datei".</param>
/// <param name="Hinweis">Klartext, wenn es nicht der Regelweg war; sonst null.</param>
public sealed record EntwurfErgebnisDto(string Weg, string? Hinweis)
{
    public static EntwurfErgebnisDto From(EntwurfErgebnis ergebnis) => new(
        ergebnis.Weg == EntwurfWeg.Outlook ? "outlook" : "datei",
        ergebnis.Hinweis);
}
