using AutomationService.Core.Persistence;
using MimeKit;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Hebt die Dateien auf, die eine erfasste Antwort mitbringt (§4.3), damit sie
/// beim Versand zum Anhängen bereitstehen (§4.7).
///
/// Hintergrund ist eine Beobachtung in der Kanzlei: Der Anwalt zieht genau
/// diese Dateien im Mailprogramm von Hand in die ausgehende Nachricht. Der
/// Monitor ruft die Nachricht ohnehin vollständig ab — sie danach wegzuwerfen
/// und den Anwalt nachbauen zu lassen, was schon da war, ist die eine Stelle,
/// an der die App ihm Arbeit abnehmen kann, ohne mehr zu wissen als er.
///
/// <b>Kein Posteingang.</b> Aufgehoben wird nur, was an einer erfassten Antwort
/// hängt — nicht der Inhalt beliebiger Nachrichten (Abschnitt 8).
/// </summary>
public static class AntwortAnhaenge
{
    /// <summary>
    /// Zusammen mehr als das gehört nicht in einen Ordner, den niemand
    /// aufräumt. Die Dateien einer Zentralruf-Antwort bleiben weit darunter.
    /// </summary>
    private const long MaxGesamtBytes = 50L * 1024 * 1024;

    /// <summary>
    /// Legt die Anhänge unter einem eigenen Ordner je Antwort ab und liefert
    /// die vollständigen Pfade. Leere Liste, wenn nichts dranhing oder das
    /// Schreiben fehlschlug — ein Anhang, den man nicht sichern kann, darf die
    /// Erfassung der Antwort nicht verhindern.
    /// </summary>
    public static IReadOnlyList<string> LegeAb(MimeMessage nachricht, string dedupeKey, ILogger logger)
    {
        // Bewusst eine Schleife statt LINQ: Sowohl der Dateiname als auch der
        // Inhalt eines MimePart sind nullbar, und nur so sieht der Compiler,
        // dass beides geprueft ist.
        var anhaenge = new List<(string Name, IMimeContent Inhalt)>();
        foreach (var teil in nachricht.Attachments.OfType<MimePart>())
        {
            var name = teil.FileName;
            var inhalt = teil.Content;
            if (!string.IsNullOrWhiteSpace(name) && inhalt is not null)
            {
                anhaenge.Add((name, inhalt));
            }
        }

        if (anhaenge.Count == 0)
        {
            return [];
        }

        try
        {
            var ordner = Path.Combine(AppDataPaths.EnsureAnhaengeDirectory(), OrdnerName(dedupeKey));
            Directory.CreateDirectory(ordner);

            var pfade = new List<string>(anhaenge.Count);
            long gesamt = 0;

            foreach (var (name, inhalt) in anhaenge)
            {
                var ziel = FreierPfad(ordner, SichererName(name));
                using (var strom = File.Create(ziel))
                {
                    inhalt.DecodeTo(strom);
                }

                gesamt += new FileInfo(ziel).Length;
                if (gesamt > MaxGesamtBytes)
                {
                    File.Delete(ziel);
                    logger.LogWarning(
                        "Anhänge der Antwort {Schluessel} überschreiten {Grenze} MB — Rest übergangen.",
                        dedupeKey,
                        MaxGesamtBytes / 1024 / 1024);
                    break;
                }

                pfade.Add(ziel);
            }

            return pfade;
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ausnahme, "Anhänge der Antwort {Schluessel} konnten nicht abgelegt werden.", dedupeKey);
            return [];
        }
    }

    /// <summary>
    /// Der Dedupe-Schlüssel ist eine Message-Id und enthält alles Mögliche —
    /// spitze Klammern, Schrägstriche, At-Zeichen. Als Ordnername taugt daraus
    /// nur die entschärfte Fassung.
    /// </summary>
    private static string OrdnerName(string dedupeKey)
    {
        var sauber = new string([.. dedupeKey.Select(zeichen =>
            char.IsLetterOrDigit(zeichen) ? zeichen : '_')]);
        return sauber.Length <= 64 ? sauber : sauber[..64];
    }

    private static string SichererName(string dateiname)
    {
        var name = Path.GetFileName(dateiname);
        foreach (var verboten in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(verboten, '_');
        }

        return string.IsNullOrWhiteSpace(name) ? "Anhang" : name;
    }

    /// <summary>
    /// Zwei Anhänge derselben Mail dürfen gleich heißen — im Dateisystem nicht.
    /// </summary>
    private static string FreierPfad(string ordner, string dateiname)
    {
        var pfad = Path.Combine(ordner, dateiname);
        if (!File.Exists(pfad))
        {
            return pfad;
        }

        var stamm = Path.GetFileNameWithoutExtension(dateiname);
        var endung = Path.GetExtension(dateiname);
        for (var nummer = 2; ; nummer++)
        {
            pfad = Path.Combine(ordner, $"{stamm} ({nummer}){endung}");
            if (!File.Exists(pfad))
            {
                return pfad;
            }
        }
    }
}
