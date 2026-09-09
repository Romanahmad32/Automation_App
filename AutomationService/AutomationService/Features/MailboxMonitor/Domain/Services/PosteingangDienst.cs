using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>Eine kurze, begrenzte Verbindung pro Abruf; unabhängig vom IMAP-IDLE-Monitor.</summary>
public sealed class PosteingangDienst(MailboxConfigStore config, MicrosoftMailOAuthService oauth) : IDisposable
{
    private readonly SemaphoreSlim _zugriff = new(1, 1);

    public Task<PosteingangSeite> LadeSeiteAsync(string? cursor, CancellationToken ct) =>
        MitOrdnerAsync((folder, konto, token) => PosteingangLeser.LadeAsync(folder, konto, cursor, token), ct);

    public Task<PosteingangInhalt> LadeInhaltAsync(string id, CancellationToken ct) =>
        MitOrdnerAsync((folder, konto, token) => PosteingangText.LadeAsync(folder,
            new UniqueId(PosteingangKennung.Decode(id, konto, folder.UidValidity).Uid), token), ct);

    private async Task<T> MitOrdnerAsync<T>(Func<IMailFolder, string, CancellationToken, Task<T>> lesen, CancellationToken ct)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct, config.ChangeToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(45));
        var token = timeout.Token;
        await _zugriff.WaitAsync(token);
        try
        {
            var options = config.Current;
            if (!options.IsConfigured)
            {
                throw new PosteingangException("Bitte zuerst unter Einstellungen → E-Mail den Postfach-Zugang einrichten.", 400);
            }
            using var client = new ImapClient { Timeout = 30000 };
            await client.ConnectAsync(options.Host, options.Port,
                options.UseSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls, token);
            await MailboxAnmeldung.AuthenticateAsync(client, options, oauth, token);
            var folder = string.Equals(options.Folder, "INBOX", StringComparison.OrdinalIgnoreCase)
                ? client.Inbox : await client.GetFolderAsync(options.Folder, token);
            await folder.OpenAsync(FolderAccess.ReadOnly, token);
            var geloescht = false;
            folder.MessageExpunged += (_, _) => geloescht = true;
            var result = await lesen(folder, PosteingangKennung.KontoFuer(options), token);
            token.ThrowIfCancellationRequested();
            if (geloescht)
            {
                throw new PosteingangException("Während des Ladens wurden Nachrichten verschoben oder gelöscht. Bitte erneut laden.");
            }
            return result;
        }
        finally
        {
            _zugriff.Release();
        }
    }

    public void Dispose() => _zugriff.Dispose();
}
