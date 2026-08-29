using AutomationService.Features.MailboxMonitor.Domain.Services;
using MailKit;
using MailKit.Security;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Meldet einen MailKit-Dienst (SMTP oder IMAP) am Postfach an. Beide Wege
/// teilen sich die Zugangsdaten, deshalb steht die Fallunterscheidung genau
/// einmal hier statt in jedem Client.
/// </summary>
internal static class PostfachAnmeldung
{
    public static async Task AnmeldenAsync(
        IMailService dienst,
        SmtpZugang zugang,
        MicrosoftMailOAuthService microsoftOAuth,
        CancellationToken cancellationToken)
    {
        if (zugang.AuthMethod == MailboxAuthMethod.MicrosoftOAuth)
        {
            var token = await microsoftOAuth.GetAccessTokenSilentAsync(cancellationToken);
            if (string.IsNullOrEmpty(token))
            {
                throw new EmailVersandException(
                    EmailVersandFehler.Anmeldung,
                    "Die Microsoft-Anmeldung ist abgelaufen. Bitte in den Einstellungen unter "
                    + "\"Postfach-Zugang\" erneut mit Microsoft anmelden.");
            }

            await dienst.AuthenticateAsync(
                new SaslMechanismOAuth2(zugang.Absender, token),
                cancellationToken);
            return;
        }

        await dienst.AuthenticateAsync(zugang.Absender, zugang.AppPasswort, cancellationToken);
    }
}
