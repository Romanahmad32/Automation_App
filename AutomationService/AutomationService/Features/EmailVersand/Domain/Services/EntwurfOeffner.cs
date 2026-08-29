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
    OutlookVerbindung outlook,
    EntwurfDatei datei,
    VersandProtokoll protokoll,
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
        var inOutlook = await Task.Run(() => outlook.OeffneEntwurf(nachricht), cancellationToken);
        if (inOutlook)
        {
            await ProtokolliereAsync(nachricht, VersandWeg.OutlookEntwurf, cancellationToken);
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
            await ProtokolliereAsync(nachricht, VersandWeg.Entwurfsdatei, cancellationToken);
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

    /// <summary>
    /// Hält die Übergabe fest — als <b>übergeben</b>, nicht als gesendet.
    /// Gesendet wird im Mailprogramm, und ob es geschah, erfährt die App nie
    /// (§4.8). Ohne diesen Eintrag stünde der zweite Versandweg nirgends, und
    /// die Frage „ist das Schreiben raus?" wäre für ihn gar nicht zu stellen.
    ///
    /// Kein Zeitpunkt des Versands, sondern der der Übergabe — und keine
    /// Message-ID: Die vergibt erst das Mailprogramm.
    ///
    /// Auch <b>kein Absender</b>: Über welches Konto Outlook die Nachricht
    /// hinausschickt, entscheidet Outlook. Die Spalte trägt beim Direktversand
    /// die Adresse, von der aus gesendet wurde (<see cref="VersandEintrag"/>) —
    /// hier stattdessen den Namen des Anwalts einzutragen, hiesse zwei Wertarten
    /// in eine Spalte zu mischen; im Protokoll stünde einmal „Von: kanzlei@…"
    /// und einmal „Von: Rechtsanwalt …". Leer ist ehrlicher: Die Oberfläche
    /// lässt die Zeile dann weg.
    /// </summary>
    private Task ProtokolliereAsync(
        EmailNachricht nachricht,
        VersandWeg weg,
        CancellationToken cancellationToken) =>
        protokoll.SchreibeAsync(
            new VersandEintrag(
                nachricht.VorgangReferenz,
                DateTimeOffset.Now,
                weg,
                string.Empty,
                nachricht.An,
                nachricht.Kopie,
                nachricht.Betreff,
                [.. nachricht.AnhangPfade.Select(pfad => Anzeigename(nachricht, pfad))]),
            cancellationToken);

    /// <summary>Der Name, unter dem der Anhang beim Empfänger ankommt.</summary>
    private static string Anzeigename(EmailNachricht nachricht, string pfad) =>
        nachricht.AnhangNamen?.TryGetValue(pfad, out var name) == true && name.Length > 0
            ? name
            : Path.GetFileName(pfad);
}
