using AutomationService.Features.Settings.Domain.Persistence;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Zugriff auf den einen Kanzlei-Einstellungssatz (Single-Row, Req. 3.1/3.2).
/// Liegt noch kein Satz vor, liefert <see cref="GetAsync"/> die Standardwerte,
/// ohne sie zu persistieren.
/// </summary>
public interface IKanzleiSettingsRepository
{
    Task<KanzleiSettingsEntity> GetAsync(CancellationToken cancellationToken = default);

    Task<KanzleiSettingsEntity> SaveAsync(
        KanzleiSettingsEntity settings,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Zählt die laufende Auftragsnummer um eins hoch (nach Abschluss eines
    /// Vorgangs, Req. 3.2) und gibt den gespeicherten Stand zurück.
    /// </summary>
    Task<KanzleiSettingsEntity> ErhoeheAuftragsnummerAsync(
        CancellationToken cancellationToken = default);
}
