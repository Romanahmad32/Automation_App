using AutomationService.Features.Versicherer.Domain.Persistence;

namespace AutomationService.Features.Versicherer.Presentation.Dtos;

/// <summary>Ein gelernter Versicherer, wie ihn die Oberfläche abruft.</summary>
public sealed record VersichererDto(
    int Id,
    string Name,
    string? Strasse,
    string? Plz,
    string? Ort,
    string? Telefon,
    string? Fax,
    string? Email,
    DateTime ZuletztAktualisiertAm,
    string? Quelle)
{
    public static VersichererDto From(VersichererEntity entity) => new(
        entity.Id,
        entity.Name,
        entity.Strasse,
        entity.Plz,
        entity.Ort,
        entity.Telefon,
        entity.Fax,
        entity.Email,
        entity.ZuletztAktualisiertAm,
        entity.Quelle);
}
