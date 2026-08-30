using AutomationService.Features.Mandanten.Domain.Services;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Ein Ausschnitt des Registers für die Mandantenliste: die Mandanten dieser
/// Seite und die beiden Zahlen, die sie einordnen.
///
/// <c>Gesamt</c> ist der ganze Bestand, <c>Gefiltert</c> die Zahl der Treffer
/// der Suche — bei leerer Suche sind beide gleich. Aus <c>Gefiltert</c> liest
/// die Oberfläche, ob es weiterzublättern gibt; die Zahl der schon geholten
/// Zeilen allein sagt das nicht.
/// </summary>
public sealed record MandantenSeiteDto(
    IReadOnlyList<MandantDto> Mandanten,
    int Gesamt,
    int Gefiltert)
{
    public static MandantenSeiteDto From(MandantenSeite seite) => new(
        [.. seite.Mandanten.Select(MandantDto.From)],
        seite.Gesamt,
        seite.Gefiltert);
}
