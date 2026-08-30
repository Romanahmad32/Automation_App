using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>Ein Ordner, für den entschieden ist, dass er keinem Mandanten gehört.</summary>
public sealed record OrdnerStatusDto(
    string Ordnername,
    string Status,
    DateTime GesetztAm)
{
    public static OrdnerStatusDto From(OrdnerStatusEntity entity) => new(
        entity.Ordnername,
        entity.Status,
        entity.GesetztAm);
}

/// <summary>
/// Setzt oder nimmt den Vermerk für mehrere Ordner auf einmal zurück.
/// <see cref="Status"/> <c>null</c> heißt: zurück in den Zuordnungsstapel.
/// </summary>
public sealed record SetzeOrdnerStatusDto(
    IReadOnlyList<string> Ordnernamen,
    string? Status);
