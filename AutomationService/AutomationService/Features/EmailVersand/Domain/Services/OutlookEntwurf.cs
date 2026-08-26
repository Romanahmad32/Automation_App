using System.Net;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Legt die Nachricht als Entwurf im installierten Outlook an und zeigt sie
/// (§4.7).
///
/// Late Binding über die ProgID statt der Interop-PIAs — dieselbe Begründung
/// wie bei <c>WordInteropPdfConversionService</c>: Die PIA-Assemblys sind unter
/// .NET ohne GAC zur Laufzeit nicht auflösbar und würden den Prozess crashen.
///
/// Die Signatur setzt Outlook selbst ein, sobald der Entwurf einen Inspector
/// bekommt. Deshalb wird sie erst angefordert und der eigene Text davorgehängt;
/// wer <c>HTMLBody</c> vorher setzt, überschreibt sie (§4.7 „Signatur").
/// </summary>
public sealed class OutlookEntwurf(ILogger<OutlookEntwurf> logger)
{
    /// <summary>OlItemType.olMailItem.</summary>
    private const int OlMailItem = 0;

    /// <summary>
    /// Ein kalt startendes Outlook braucht spürbar länger als ein laufendes.
    /// Läuft es danach immer noch nicht, ist der Dateiweg schneller als weiter
    /// zu warten.
    /// </summary>
    private static readonly TimeSpan Geduld = TimeSpan.FromSeconds(60);

    /// <summary>
    /// True, wenn der Entwurf offen auf dem Schirm steht. False heißt nur „hier
    /// nicht" — kein Fehler, sondern das Stichwort für den Dateiweg.
    /// </summary>
    public bool Oeffne(EmailNachricht nachricht)
    {
        if (!OperatingSystem.IsWindows())
        {
            return false;
        }

        Exception? fehler = null;
        var geoeffnet = false;

        // Outlook-COM verlangt einen STA-Thread. Ein kurzlebiger genügt: Anders
        // als die Serienkonvertierung in Word ist das ein seltener Einzelaufruf,
        // für den sich kein dauerhafter Arbeiter lohnt.
        var thread = new Thread(() =>
        {
            try
            {
                geoeffnet = Versuche(nachricht);
            }
            catch (Exception ausnahme)
            {
                fehler = ausnahme;
            }
        })
        {
            IsBackground = true,
            Name = "OutlookEntwurf",
        };

        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();

        if (!thread.Join(Geduld))
        {
            logger.LogWarning(
                "Outlook hat den Entwurf nicht innerhalb von {Sekunden} Sekunden geöffnet.",
                Geduld.TotalSeconds);
            return false;
        }

        if (fehler is not null)
        {
            logger.LogWarning(fehler, "Der Entwurf ließ sich nicht in Outlook öffnen.");
            return false;
        }

        return geoeffnet;
    }

    private static bool Versuche(EmailNachricht nachricht)
    {
        if (!OperatingSystem.IsWindows())
        {
            return false;
        }

        var typ = Type.GetTypeFromProgID("Outlook.Application");
        if (typ is null)
        {
            return false;
        }

        dynamic? outlook = Activator.CreateInstance(typ);
        if (outlook is null)
        {
            return false;
        }

        dynamic entwurf = outlook.CreateItem(OlMailItem);
        entwurf.To = string.Join("; ", Brauchbare(nachricht.An));

        var kopie = Brauchbare(nachricht.Kopie);
        if (kopie.Count > 0)
        {
            entwurf.CC = string.Join("; ", kopie);
        }

        entwurf.Subject = nachricht.Betreff;

        // Outlook hängt die Dateien selbst an — die Bytes hier zu laden wäre
        // Arbeit für den Papierkorb. Dass sie lesbar sind, hat der Aufrufer
        // bereits geprüft.
        foreach (var pfad in nachricht.AnhangPfade.Where(pfad => !string.IsNullOrWhiteSpace(pfad)))
        {
            entwurf.Attachments.Add(pfad);
        }

        // Den Inspector anzufassen lässt Outlook seine Signatur einsetzen.
        _ = entwurf.GetInspector;
        var signatur = (object?)entwurf.HTMLBody as string ?? string.Empty;
        entwurf.HTMLBody = AlsHtml(nachricht.Text) + signatur;

        entwurf.Display();
        return true;
    }

    private static IReadOnlyList<string> Brauchbare(IReadOnlyList<string> adressen) =>
        [.. adressen.Select(adresse => adresse.Trim()).Where(adresse => adresse.Length > 0)];

    /// <summary>
    /// Der Text als schlichtes HTML. Outlook führt den Entwurf über
    /// <c>HTMLBody</c> — nur so bleibt die Signatur erhalten, die es selbst
    /// eingesetzt hat. Escapen ist Pflicht: Ein „&amp;" im Aktenzeichen oder
    /// spitze Klammern um eine Adresse dürfen nicht als Auszeichnung gelesen
    /// werden.
    /// </summary>
    private static string AlsHtml(string text) =>
        "<div>"
        + WebUtility.HtmlEncode(text).Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace("\n", "<br>", StringComparison.Ordinal)
        + "</div>";
}
