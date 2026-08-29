using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Eine im Mailprogramm gefundene Signatur (REQUIREMENTS.md §4.7).
/// </summary>
/// <param name="Name">Anzeigename in Outlook.</param>
/// <param name="Text">Outlooks eigene Nur-Text-Fassung, fuer die Vorschau.</param>
/// <param name="HatFormat">
/// True, wenn daneben eine formatierte Fassung liegt (Schrift, Farben, Logo).
/// Wie schwer deren Bilder wiegen, sagt erst die Übernahme.
/// </param>
public sealed record OutlookSignaturDto(string Name, string Text, bool HatFormat)
{
    public static OutlookSignaturDto From(OutlookSignatur signatur) =>
        new(signatur.Name, signatur.Text, signatur.HatFormat);
}
