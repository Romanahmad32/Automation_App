using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Zugriff auf die Mail-Textvorlagen (§4.7, §5.3). Vergibt Ids und wacht über
/// die Eindeutigkeit des Namens.
/// </summary>
public interface IMailVorlagenRepository
{
    /// <summary>Alle Vorlagen, nach Namen sortiert — so stehen sie zur Auswahl.</summary>
    Task<IReadOnlyList<MailVorlageEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <exception cref="MailVorlageNameConflictException">Name bereits vergeben.</exception>
    Task<MailVorlageEntity> CreateAsync(MailVorlageEntity neu, CancellationToken cancellationToken = default);

    /// <summary>Liefert null, wenn die Id unbekannt ist.</summary>
    /// <exception cref="MailVorlageNameConflictException">Name bereits von einer anderen vergeben.</exception>
    Task<MailVorlageEntity?> UpdateAsync(MailVorlageEntity vorlage, CancellationToken cancellationToken = default);

    /// <summary>Löscht die Vorlage. false, wenn die Id unbekannt war.</summary>
    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
