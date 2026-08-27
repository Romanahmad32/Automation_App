using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Die Signatur, wie sie nach einer Übernahme in den Einstellungen liegt
/// (REQUIREMENTS.md §4.7).
///
/// Die HTML-Fassung selbst steht bewusst nicht darin: Sie ist zehntausende
/// Zeichen groß, die Oberfläche zeigt sie nicht an und kann sie nicht
/// bearbeiten. Was sie wissen muss, ist, <b>dass</b> es eine gibt und welche
/// Bilder darin stecken.
/// </summary>
public sealed record SignaturStandDto(
    string Text,
    bool HatFormat,
    IReadOnlyList<SignaturBildDto> Bilder)
{
    public static SignaturStandDto From(SignaturBlock block) => new(
        block.Text,
        block.Html.Length > 0,
        [.. block.Bilder.Select(SignaturBildDto.From)]);
}
