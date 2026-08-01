using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Ausgang einer Referenzänderung: umbenannt, Ausgangsreferenz unbekannt oder
/// Zielreferenz bereits durch einen anderen Vorgang belegt.
/// </summary>
public enum ReferenzAenderungStatus
{
    Geaendert,
    NichtGefunden,
    Vergeben,
}

/// <summary>
/// Ergebnis von <see cref="IVorgangRepository.RenameReferenzAsync"/>.
/// <see cref="Vorgang"/> ist nur bei <see cref="ReferenzAenderungStatus.Geaendert"/> gesetzt.
/// </summary>
public sealed record ReferenzAenderung(
    ReferenzAenderungStatus Status,
    VorgangEntity? Vorgang = null);
