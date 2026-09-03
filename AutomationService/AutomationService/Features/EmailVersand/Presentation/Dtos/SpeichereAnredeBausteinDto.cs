using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Eingabe zum Anlegen eines Anredeanfangs; Id und Reihenfolge vergibt der
/// Bestand, wenn nichts mitkommt.
/// </summary>
public sealed record SpeichereAnredeBausteinDto(
    string Maennlich,
    string Weiblich,
    string Neutral,
    int Sortierung)
{
    public AnredeBausteinEntity ToEntity() => new()
    {
        Maennlich = Maennlich,
        Weiblich = Weiblich,
        Neutral = Neutral,
        Sortierung = Sortierung,
    };
}
