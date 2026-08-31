using AutomationService.Features.Sachgebiete.Domain.Persistence;

namespace AutomationService.Features.Sachgebiete.Domain.Services;

/// <summary>Lesezugriff auf den Sachgebietskatalog der Kanzlei (§7.1).</summary>
public interface ISachgebietKatalog
{
    /// <summary>Alle Einträge in Katalogreihenfolge — auch inaktive, damit der Bestand lesbar bleibt.</summary>
    Task<IReadOnlyList<SachgebietEntity>> GetAllAsync(CancellationToken cancellationToken);
}
