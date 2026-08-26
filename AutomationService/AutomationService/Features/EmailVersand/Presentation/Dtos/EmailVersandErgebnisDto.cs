using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>Was der Versand ergeben hat (REQUIREMENTS.md §4.7).</summary>
public sealed record EmailVersandErgebnisDto(
    DateTimeOffset GesendetAm,
    IReadOnlyList<string> Empfaenger,
    bool ImGesendetOrdner,
    string? Hinweis)
{
    public static EmailVersandErgebnisDto From(EmailVersandErgebnis ergebnis) => new(
        ergebnis.GesendetAm,
        ergebnis.Empfaenger,
        ergebnis.ImGesendetOrdner,
        ergebnis.Hinweis);
}
