using AutomationService.Features.MailboxMonitor.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Öffnet den Entwurf: erst in Outlook, sonst als Datei (§4.7).
///
/// Die Reihenfolge ist der ganze Zweck. In Outlook stehen Signatur und Vorlage
/// der Kanzlei bereits, und dorthin zieht der Anwalt aus einer erhaltenen
/// Nachricht an, was die App nicht kennt — genau die Arbeitsweise, die dieser
/// Weg treffen soll. Die Datei ist nur die Zusicherung, dass er auch ohne
/// Outlook nicht abbricht.
/// </summary>
public sealed class EntwurfOeffner(
    MailboxConfigStore configStore,
    OutlookEntwurf outlook,
    EntwurfDatei datei,
    IOptions<EmailVersandOptions> optionen) : IEntwurfOeffner
{
    public async Task<EntwurfErgebnis> OeffneAsync(
        EmailNachricht nachricht,
        CancellationToken cancellationToken)
    {
        var einstellungen = optionen.Value;

        // Dieselbe Prüfung wie beim Versand (§4.7 „Alles oder nichts"): Ein
        // fehlender Anhang soll auffallen, bevor ein Fenster aufgeht, das nach
        // fertiger Arbeit aussieht.
        AnhangPruefung.Pruefe(nachricht.AnhangPfade, einstellungen.MaxAnhangGesamtMb);

        // Der COM-Aufruf blockiert bis zu einer Minute — nicht auf dem Thread,
        // der die Anfrage bedient.
        var inOutlook = await Task.Run(() => outlook.Oeffne(nachricht), cancellationToken);
        if (inOutlook)
        {
            return new EntwurfErgebnis(EntwurfWeg.Outlook, null);
        }

        var anhaenge = AnhangPruefung.Lade(
            nachricht.AnhangPfade,
            einstellungen.MaxAnhangGesamtMb,
            nachricht.AnhangNamen);
        var absender = SmtpZugang.Aus(configStore.Current, einstellungen)?.Absender ?? string.Empty;
        var mime = EmailNachrichtBauer.Baue(nachricht, absender, anhaenge);

        if (datei.Oeffne(mime))
        {
            return new EntwurfErgebnis(
                EntwurfWeg.Datei,
                "Outlook war nicht erreichbar. Der Entwurf wurde als Datei geöffnet — die "
                + "Signatur der Kanzlei fehlt darin und ist vor dem Senden zu ergänzen.");
        }

        throw new EmailVersandException(
            EmailVersandFehler.Entwurf,
            "Der Entwurf ließ sich weder in Outlook noch als Datei öffnen. Ist auf diesem "
            + "Rechner ein Mailprogramm eingerichtet?");
    }
}
