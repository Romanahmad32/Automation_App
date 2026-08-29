using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Ein Bild der formatierten Signatur mit seiner Größe (REQUIREMENTS.md §4.7).
/// Die Größe geht mit, weil der Anwalt je Mail entscheidet, ob das Bild
/// mitgeht — und diese Entscheidung ohne Zahl nicht zu treffen ist.
/// </summary>
public sealed record SignaturBildDto(string Dateiname, long Bytes)
{
    public static SignaturBildDto From(SignaturBild bild) => new(bild.Dateiname, bild.Bytes);
}
