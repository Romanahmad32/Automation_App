using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Ob die App senden kann und von welcher Adresse aus (REQUIREMENTS.md §4.7).
/// </summary>
public sealed record EmailVersandBereitschaftDto(bool Bereit, string Absender, string? Hinweis)
{
    public static EmailVersandBereitschaftDto From(EmailVersandBereitschaft bereitschaft) => new(
        bereitschaft.Bereit,
        bereitschaft.Absender,
        bereitschaft.Hinweis);
}
