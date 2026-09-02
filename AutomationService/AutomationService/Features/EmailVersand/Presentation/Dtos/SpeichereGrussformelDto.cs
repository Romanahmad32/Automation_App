using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Eingabe zum Anlegen einer Grußformel; Id und Reihenfolge vergibt der
/// Bestand, wenn nichts mitkommt.
/// </summary>
public sealed record SpeichereGrussformelDto(string Text, int Sortierung)
{
    public GrussformelEntity ToEntity() => new() { Text = Text, Sortierung = Sortierung };
}
