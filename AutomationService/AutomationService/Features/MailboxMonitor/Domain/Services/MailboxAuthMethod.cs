namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Wie sich der Monitor am IMAP-Postfach anmeldet.
/// </summary>
public enum MailboxAuthMethod
{
    /// <summary>
    /// Gewöhnliche IMAP-Anmeldung mit Benutzername + Passwort. Bei 1&amp;1/IONOS
    /// ist das das Postfach-Passwort, bei Gmail ein eigens erzeugtes
    /// App-Passwort (2FA aktivieren). Microsoft/Outlook akzeptiert diesen Weg
    /// seit September 2024 nicht mehr.
    ///
    /// Der Name bleibt <c>AppPassword</c>, weil er im HTTP-Vertrag und in der
    /// gespeicherten Konfiguration steht — umbenennen hieße, beide Seiten und
    /// bestehende Installationen anzufassen, ohne dass sich etwas ändert.
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
