namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Wie sich der Monitor am IMAP-Postfach anmeldet.
/// </summary>
public enum MailboxAuthMethod
{
    /// <summary>
    /// Benutzername + App-Passwort (Gmail-Weg: 2FA aktivieren, App-Passwort
    /// erzeugen). Microsoft/Outlook akzeptiert diesen Weg seit September 2024
    /// nicht mehr.
    /// </summary>
    AppPassword,

    /// <summary>
    /// OAuth2 über eine Microsoft-Anmeldung im Browser (XOAUTH2). Der einzige
    /// noch unterstützte Weg für Outlook.com- und Microsoft-365-Postfächer;
    /// für den Nutzer der einfachste: einmal „Mit Microsoft anmelden" klicken,
    /// kein App-Passwort nötig.
    /// </summary>
    MicrosoftOAuth,
}
