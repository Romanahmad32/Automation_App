using System.Net;
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
/// </summary>
internal static class OutlookNachricht
{
    /// <summary>OlItemType.olMailItem.</summary>
    private const int OlMailItem = 0;

    public static bool Zeige(dynamic outlook, EmailNachricht nachricht)
    {
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
            entwurf.Attachments.Add(UnterGewuenschtemNamen(pfad, nachricht.AnhangNamen));
        }

        // Den Inspector anzufassen lässt Outlook seine Signatur einsetzen;
        // deshalb wird der eigene Text davorgehängt statt HTMLBody zu setzen.
        dynamic inspector = entwurf.GetInspector;
        var signatur = (object?)entwurf.HTMLBody as string ?? string.Empty;
        entwurf.HTMLBody = AlsHtml(nachricht.Text) + signatur;

        entwurf.Display();

        // Ohne Activate erscheint das Fenster hinter der App — der Anwalt sieht
        // dann nichts und hält den Vorgang für hängengeblieben.
        try
        {
            inspector.Activate();
        }
        catch (COMException)
        {
            // Das Fenster steht; wo es steht, ist kein Grund zu scheitern.
        }

        return true;
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
