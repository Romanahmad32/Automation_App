using AutomationService.Features.MailboxMonitor.Domain.Services;
using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;
using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Trägt eine gesendete Nachricht per IMAP in den Ordner "Gesendet" nach.
/// Hintergrund: §4.7 nennt diesen Ordner als einzigen Versandnachweis, aber
/// nicht jeder Anbieter legt eine über SMTP eingelieferte Mail von sich aus
/// dort ab (Gmail tut es, andere nicht).
///
/// Schlägt das Nachtragen fehl, ist das <b>kein</b> Fehler des Versands: Die
/// Mail ist beim Empfänger. Deshalb wirft diese Klasse nicht, sondern meldet
/// den Misserfolg zurück, damit die Oberfläche einen Hinweis zeigen kann.
/// </summary>
public sealed class GesendetOrdnerAblage(
    IMailboxConfigSource configStore,
    MicrosoftMailOAuthService microsoftOAuth,
    ILogger<GesendetOrdnerAblage> logger) : IGesendetOrdnerAblage
{
    public async Task<bool> LegeAbAsync(
        MimeMessage nachricht,
        SmtpZugang zugang,
        CancellationToken cancellationToken)
    {
        var postfach = configStore.Current;

        try
        {
            using var client = new ImapClient();
            await client.ConnectAsync(
                postfach.Host,
                postfach.Port,
                postfach.UseSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTls,
                cancellationToken);
            await PostfachAnmeldung.AnmeldenAsync(client, zugang, microsoftOAuth, cancellationToken);

            var ordner = await FindeGesendetAsync(client, cancellationToken);
            if (ordner is null)
            {
                logger.LogWarning("Kein Ordner \"Gesendet\" im Postfach gefunden — keine Kopie abgelegt.");
                return false;
            }

            await ordner.OpenAsync(FolderAccess.ReadWrite, cancellationToken);
            // Als gelesen markieren: Eine selbst gesendete Mail als ungelesenen
            // Eingang zu zeigen, waere ein falscher Hinweis im Mailprogramm.
            await ordner.AppendAsync(nachricht, MessageFlags.Seen, cancellationToken);
            await client.DisconnectAsync(quit: true, cancellationToken);
            return true;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogWarning(
                exception,
                "Die Kopie im Ordner \"Gesendet\" konnte nicht abgelegt werden. Die Mail ist versendet.");
            return false;
        }
    }

    /// <summary>
    /// Sucht den Gesendet-Ordner. Der Sonderordner ist der verlaessliche Weg
    /// (SPECIAL-USE bzw. XLIST); fehlt er, wird nach den ueblichen Namen
    /// gesucht, bevor aufgegeben wird.
    /// </summary>
    private static async Task<IMailFolder?> FindeGesendetAsync(
        ImapClient client,
        CancellationToken cancellationToken)
    {
        try
        {
            var sonderordner = client.GetFolder(SpecialFolder.Sent);
            if (sonderordner is not null)
            {
                return sonderordner;
            }
        }
        catch (NotSupportedException)
        {
            // Der Server kennt keine Sonderordner (kein SPECIAL-USE/XLIST).
        }

        string[] namen = ["Sent", "Sent Items", "Gesendet", "Gesendete Elemente", "Gesendete Objekte"];
        foreach (var name in namen)
        {
            try
            {
                return await client.GetFolderAsync(name, cancellationToken);
            }
            catch (FolderNotFoundException)
            {
                // Nächster Name.
            }
        }

        return null;
    }
}
