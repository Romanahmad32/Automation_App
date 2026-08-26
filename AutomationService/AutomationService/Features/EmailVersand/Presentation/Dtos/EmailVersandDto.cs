using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Die zu versendende Mail, wie die Oberfläche sie schickt (REQUIREMENTS.md §4.7).
/// Die Absenderadresse steht bewusst nicht darin — sie ergibt sich aus dem
/// hinterlegten Postfach-Zugang und ist nichts, was der Aufrufer bestimmen darf.
/// </summary>
public sealed record EmailVersandDto(
    IReadOnlyList<string> An,
    IReadOnlyList<string>? Kopie,
    string Betreff,
    string Text,
    IReadOnlyList<string>? AnhangPfade,
    string? AbsenderName,
    IReadOnlyDictionary<string, string>? AnhangNamen)
{
    public EmailNachricht ToDomain() => new(
        An ?? [],
        Kopie ?? [],
        Betreff ?? string.Empty,
        Text ?? string.Empty,
        AnhangPfade ?? [],
        AbsenderName ?? string.Empty,
        AnhangNamen);
}
