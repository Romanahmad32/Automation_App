using AutomationService.Features.Sachgebiete.Domain.Persistence;

namespace AutomationService.Features.Sachgebiete.Presentation.Dtos;

/// <summary>Ein Katalogeintrag, wie ihn die Auswahllisten der Oberfläche abrufen.</summary>
public sealed record SachgebietDto(
    int Id,
    string Kuerzel,
    string Name,
    string RechtsgebietVorschlag,
    int Sortierung,
    bool Aktiv)
{
    public static SachgebietDto From(SachgebietEntity entity) => new(
        entity.Id,
        entity.Kuerzel,
        entity.Name,
        entity.RechtsgebietVorschlag,
        entity.Sortierung,
        entity.Aktiv);
}
