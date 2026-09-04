using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Ein Bild der formatierten Signatur mit seiner Größe (REQUIREMENTS.md §4.7).
/// Die Größe geht mit, weil der Anwalt je Mail entscheidet, ob das Bild
/// mitgeht — und diese Entscheidung ohne Zahl nicht zu treffen ist.
/// </summary>
/// <param name="Dateiname">Der Name, unter dem der Dienst es ausliefert.</param>
/// <param name="Bytes">Wie schwer es wiegt.</param>
/// <param name="Marke">
/// Sein Inhalt in Kurzform (<see cref="SignaturMarke"/>) — gehört an die
/// Adresse, unter der die Oberfläche das Bild holt. Ohne sie heißen zwei
/// verschiedene Logos beide <c>image001.png</c>, und die Oberfläche zeigt nach
/// einem Signaturwechsel weiter das alte aus ihrem Bildspeicher.
/// </param>
public sealed record SignaturBildDto(string Dateiname, long Bytes, string Marke)
{
    public static SignaturBildDto From(SignaturBild bild) =>
        new(bild.Dateiname, bild.Bytes, bild.Marke);
}
