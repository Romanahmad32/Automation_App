using MailKit.Net.Imap;
using MailKit.Security;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Meldet eine frische IMAP-Verbindung am Server an — Passwort-Weg für
/// gewöhnliche IMAP-Postfächer (1&amp;1/IONOS, Gmail), Outlook-Weg mit einem
/// still erneuerten Microsoft-OAuth-Token
/// (XOAUTH2, seit Microsoft im September 2024 IMAP-Basisauthentifizierung
/// abgeschaltet hat).
/// </summary>
public static class MailboxAnmeldung
{
    /// <exception cref="AuthenticationException">
    /// Die Microsoft-Anmeldung fehlt. Die Meldung landet als Status in der
    /// Oberfläche; die erfolgreiche Anmeldung stößt über das Änderungssignal
    /// sofort den nächsten Verbindungsversuch an.
    /// </exception>
    public static async Task AuthenticateAsync(
        ImapClient client,
        MailboxOptions options,
        MicrosoftMailOAuthService microsoftOAuth,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(client);
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(microsoftOAuth);

        if (options.AuthMethod == MailboxAuthMethod.MicrosoftOAuth)
        {
            var accessToken = await microsoftOAuth.GetAccessTokenSilentAsync(cancellationToken)
                ?? throw new AuthenticationException(
                    "Microsoft-Anmeldung erforderlich: Bitte in den Einstellungen unter " +
                    "Postfach-Zugang auf „Mit Microsoft anmelden“ klicken.");
            await client.AuthenticateAsync(new SaslMechanismOAuth2(options.Username, accessToken), cancellationToken);
            return;
        }

        await client.AuthenticateAsync(options.Username, options.AppPassword, cancellationToken);
    }
}
