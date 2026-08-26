using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Eine im Mailprogramm gefundene Signatur (REQUIREMENTS.md §4.7).
/// </summary>
public sealed record OutlookSignaturDto(string Name, string Text)
{
    public static OutlookSignaturDto From(OutlookSignatur signatur) =>
        new(signatur.Name, signatur.Text);
}
