using System.Diagnostics;
using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Schreibt die Nachricht als <c>.eml</c> und lässt sie vom eingerichteten
/// Mailprogramm öffnen — der Ausweichweg, wenn Outlook nicht da ist (§4.7).
///
/// Ohne Signatur: Die steht im Mailprogramm, und was dort eingerichtet ist,
/// kann die App von außen nicht wissen. Der Anwalt ergänzt sie vor dem Senden.
/// </summary>
public sealed class EntwurfDatei(ILogger<EntwurfDatei> logger)
{
    public bool Oeffne(MimeMessage nachricht)
    {
        try
        {
            var ordner = Path.Combine(Path.GetTempPath(), "AutomationService", "Entwuerfe");
            Directory.CreateDirectory(ordner);

            // Zeitstempel im Namen: Zwei Entwürfe nacheinander sollen sich nicht
            // gegenseitig überschreiben, solange der erste noch offen ist.
            var pfad = Path.Combine(ordner, $"Entwurf_{DateTimeOffset.Now:yyyyMMdd_HHmmss}.eml");
            nachricht.WriteTo(pfad);

            Process.Start(new ProcessStartInfo(pfad) { UseShellExecute = true });
            return true;
        }
        catch (Exception ausnahme)
        {
            logger.LogWarning(ausnahme, "Die Entwurfsdatei ließ sich nicht öffnen.");
            return false;
        }
    }
}
