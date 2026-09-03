using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Übertragungsformat einer persönlichen Grußformel (§4.7). PascalCase wird als
/// camelCase serialisiert und passt damit 1:1 zur Flutter-Entität
/// <c>Grussformel</c>.
/// </summary>
public sealed record GrussformelDto(int Id, string Text, int Sortierung)
{
    public static GrussformelDto From(GrussformelEntity e) => new(e.Id, e.Text, e.Sortierung);

    public GrussformelEntity ToEntity() =>
        new() { Id = Id, Text = Text, Sortierung = Sortierung };
}
