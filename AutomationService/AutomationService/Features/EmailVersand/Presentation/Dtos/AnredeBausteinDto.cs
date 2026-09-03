using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Übertragungsformat eines Anredeanfangs (§4.7). PascalCase wird als camelCase
/// serialisiert und passt damit 1:1 zur Flutter-Entität <c>Anredebaustein</c>.
/// </summary>
public sealed record AnredeBausteinDto(
    int Id,
    string Maennlich,
    string Weiblich,
    string Neutral,
    int Sortierung)
{
    public static AnredeBausteinDto From(AnredeBausteinEntity e) =>
        new(e.Id, e.Maennlich, e.Weiblich, e.Neutral, e.Sortierung);

    public AnredeBausteinEntity ToEntity() => new()
    {
        Id = Id,
        Maennlich = Maennlich,
        Weiblich = Weiblich,
        Neutral = Neutral,
        Sortierung = Sortierung,
    };
}
