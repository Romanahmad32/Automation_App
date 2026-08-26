using System.Security.Cryptography;
using System.Text;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Verschluesselt das Postfach-Passwort fuer die Ablage auf Platte
/// (Windows-DPAPI, gebunden an das angemeldete Benutzerkonto) — dieselbe
/// Absicherung, die auch der MSAL-Token-Cache verwendet.
///
/// Hintergrund: Beim OAuth-Weg liegt nie ein Passwort auf Platte, und ein
/// Gmail-App-Passwort laesst sich einzeln widerrufen. Ein IMAP-Passwort bei
/// Anbietern ohne App-Passwort-Konzept (1&amp;1/IONOS) ist dagegen das Passwort
/// des Postfachs selbst — im Klartext neben der Konfiguration oeffnet es die
/// gesamte Mandantenkorrespondenz.
///
/// Faellt das Ver- oder Entschluesseln aus, wird <b>nicht</b> geworfen: Ein
/// unlesbares Passwort ist ein "bitte neu eingeben", kein Grund, den Dienst
/// nicht starten zu lassen. Der Aufrufer bekommt null und meldet es.
/// </summary>
public static class PasswortSchutz
{
    /// <summary>
    /// Verschluesselt fuer die Ablage. Leere Eingabe bleibt leer (es gibt nichts
    /// zu schuetzen); null bedeutet, dass das Verschluesseln fehlgeschlagen ist.
    /// </summary>
    public static string? Schuetze(string klartext)
    {
        if (string.IsNullOrEmpty(klartext))
        {
            return string.Empty;
        }

        try
        {
            var geschuetzt = ProtectedData.Protect(
                Encoding.UTF8.GetBytes(klartext),
                optionalEntropy: null,
                DataProtectionScope.CurrentUser);
            return Convert.ToBase64String(geschuetzt);
        }
        catch (CryptographicException)
        {
            return null;
        }
    }

    /// <summary>
    /// Liest einen mit <see cref="Schuetze"/> abgelegten Wert zurueck. null,
    /// wenn er nicht entschluesselt werden kann — etwa weil die Datei aus einem
    /// anderen Windows-Benutzerkonto stammt oder beschaedigt ist.
    /// </summary>
    public static string? Entschuetze(string geschuetzt)
    {
        if (string.IsNullOrEmpty(geschuetzt))
        {
            return string.Empty;
        }

        try
        {
            var klartext = ProtectedData.Unprotect(
                Convert.FromBase64String(geschuetzt),
                optionalEntropy: null,
                DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(klartext);
        }
        catch (Exception exception) when (exception is CryptographicException or FormatException)
        {
            return null;
        }
    }
}
