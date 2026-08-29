using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Baut aus der fachlichen Nachricht das Outlook-Entwurfsfenster und zeigt es
/// (§4.7). Getrennt von <see cref="OutlookVerbindung"/>, der sich um Lebensdauer
/// und Thread der Anwendungsinstanz kümmert — hier steht nur, wie aus einer
/// <see cref="EmailNachricht"/> ein Entwurf wird.
///
/// Alle Aufrufe laufen über Late Binding und gehören auf den STA-Thread des
/// Aufrufers; diese Klasse startet selbst nichts.
///
/// <b>Jeder Griff wird wieder losgelassen</b> (<see cref="ComFreigabe"/>): Das
/// Entwurfsfenster gehört nach <c>Display</c> Outlook selbst, unsere Verweise
/// darauf hielten sonst nur den Prozess fest.
/// </summary>
internal static class OutlookNachricht
{
    /// <summary>OlItemType.olMailItem.</summary>
    private const int OlMailItem = 0;

    public static bool Zeige(dynamic outlook, EmailNachricht nachricht)
    {
        object entwurfGriff = outlook.CreateItem(OlMailItem);
        object? fensterGriff = null;
        try
        {
            dynamic entwurf = entwurfGriff;
            entwurf.To = string.Join("; ", Brauchbare(nachricht.An));

            var kopie = Brauchbare(nachricht.Kopie);
            if (kopie.Count > 0)
            {
                entwurf.CC = string.Join("; ", kopie);
            }

            entwurf.Subject = nachricht.Betreff;
            Haenge(entwurf, nachricht);

            // Den Inspector anzufassen lässt Outlook seine Signatur einsetzen;
            // deshalb wird der eigene Text davorgehängt statt HTMLBody zu setzen.
            fensterGriff = entwurf.GetInspector;
            var signatur = (object?)entwurf.HTMLBody as string ?? string.Empty;
            entwurf.HTMLBody = TextAlsHtml.Absatz(nachricht.Text) + signatur;

            entwurf.Display();

            // Ohne Activate erscheint das Fenster hinter der App — der Anwalt
            // sieht dann nichts und hält den Vorgang für hängengeblieben.
            try
            {
                ((dynamic)fensterGriff).Activate();
            }
            catch (COMException)
            {
                // Das Fenster steht; wo es steht, ist kein Grund zu scheitern.
            }

            return true;
        }
        finally
        {
            ComFreigabe.Gib(fensterGriff, entwurfGriff);
        }
    }

    /// <summary>
    /// Hängt die Dateien an. Outlook holt sie selbst von der Platte — die Bytes
    /// hier zu laden wäre Arbeit für den Papierkorb. Dass sie lesbar sind, hat
    /// der Aufrufer bereits geprüft.
    /// </summary>
    private static void Haenge(dynamic entwurf, EmailNachricht nachricht)
    {
        object sammlungGriff = entwurf.Attachments;
        try
        {
            dynamic sammlung = sammlungGriff;
            foreach (var pfad in nachricht.AnhangPfade.Where(pfad => !string.IsNullOrWhiteSpace(pfad)))
            {
                object angehaengt = sammlung.Add(UnterGewuenschtemNamen(pfad, nachricht.AnhangNamen));
                ComFreigabe.Gib(angehaengt);
            }
        }
        finally
        {
            ComFreigabe.Gib(sammlungGriff);
        }
    }

    /// <summary>
    /// Outlook hängt Dateien unter ihrem Namen auf Platte an. Hat der Anwalt
    /// umbenannt, muss also eine Kopie unter dem gewünschten Namen her — die
    /// Datei in der Akte behält ihren. Die Kopie liegt im Temp-Ordner; sie wird
    /// nur bis zum Absenden in Outlook gebraucht.
    /// </summary>
    private static string UnterGewuenschtemNamen(
        string pfad,
        IReadOnlyDictionary<string, string>? namen)
    {
        if (namen is null || !namen.TryGetValue(pfad, out var gewuenscht))
        {
            return pfad;
        }

        var name = Path.GetFileName(gewuenscht.Trim());
        if (string.IsNullOrWhiteSpace(name)
            || string.Equals(name, Path.GetFileName(pfad), StringComparison.Ordinal))
        {
            return pfad;
        }

        try
        {
            var ordner = Path.Combine(Path.GetTempPath(), "AutomationService", "Anhaenge");
            Directory.CreateDirectory(ordner);
            var ziel = Path.Combine(ordner, name);
            File.Copy(pfad, ziel, overwrite: true);
            return ziel;
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            // Dann geht der Anhang unter seinem ursprünglichen Namen hinaus —
            // besser als gar nicht.
            return pfad;
        }
    }

    private static IReadOnlyList<string> Brauchbare(IReadOnlyList<string> adressen) =>
        [.. adressen.Select(adresse => adresse.Trim()).Where(adresse => adresse.Length > 0)];
}
