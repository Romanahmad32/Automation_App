using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Hängt die Signatur der Kanzlei unter den Mailtext (§4.7 „Signatur").
///
/// Sie steht in den Einstellungen, nicht im Entwurf: Der Anwalt pflegt sie
/// einmal — übernommen aus seinem Mailprogramm — und nicht je Mail. Deshalb
/// wird sie hier angefügt und nicht schon im Formular, wo sie bei jedem
/// Nachziehen der Anrede mitwandern müsste.
///
/// <b>Nur beim Direktversand.</b> Der Entwurf im Mailprogramm bekommt sie
/// nicht: Dort setzt Outlook seine eigene ein, und beide zusammen stünden
/// doppelt unter der Mail.
/// </summary>
public sealed class KanzleiSignatur(AutomationDbContext db)
{
    public async Task<string> UnterAsync(string text, CancellationToken cancellationToken)
    {
        var signatur = await LiesAsync(cancellationToken);
        if (signatur.Length == 0)
        {
            return text;
        }

        // Eine Leerzeile dazwischen, aber keine zweite: Der vorbelegte Text
        // endet bereits mit dem Kanzleinamen unter der Grußformel.
        return $"{text.TrimEnd()}\n\n{signatur}";
    }

    private async Task<string> LiesAsync(CancellationToken cancellationToken)
    {
        var settings = await db.KanzleiSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);

        return settings?.MailSignatur.Trim() ?? string.Empty;
    }
}
