using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Holt die Anhänge aus der Nachricht, die in Outlook gerade offen oder in der
/// Liste ausgewählt ist (§4.7).
///
/// Hintergrund ist eine Beobachtung in der Kanzlei: Dateien aus einer
/// erhaltenen Mail werden von Hand in die ausgehende gezogen — Gutachten,
/// Kostenvoranschlag, Fotos. Diese Dateien liegen nicht auf der Platte, sondern
/// nur in der Nachricht; sie zu ziehen ist deshalb der einzige Weg, der ohne
/// Zwischenspeichern auskommt. Da die App ohnehin mit Outlook spricht, fragt
/// sie stattdessen einfach nach.
///
/// Läuft auf dem STA-Thread von <see cref="OutlookVerbindung"/>.
/// </summary>
internal static class OutlookAuswahl
{
    /// <summary>PR_ATTACH_CONTENT_ID — gesetzt bei Bildern, die im Text stecken.</summary>
    private const string ContentIdEigenschaft =
        "http://schemas.microsoft.com/mapi/proptag/0x3712001F";

    /// <summary>OlObjectClass.olMail.</summary>
    private const int OlMail = 43;

    /// <summary>OlAttachmentType.olByValue — eine echte Datei, kein Verweis.</summary>
    private const int OlByValue = 1;

    public static object? Anhaenge(dynamic outlook)
    {
        var nachricht = AktuelleNachricht(outlook);
        if (nachricht is null)
        {
            return Array.Empty<string>();
        }

        var ordner = AnhangAblage.OutlookOrdner();

        var pfade = new List<string>();
        dynamic anhaenge = nachricht.Attachments;
        int anzahl = anhaenge.Count;

        // Outlook zählt ab 1, nicht ab 0.
        for (var nummer = 1; nummer <= anzahl; nummer++)
        {
            dynamic anhang = anhaenge.Item(nummer);
            if (!IstEchteDatei(anhang))
            {
                continue;
            }

            try
            {
                var ziel = FreierPfad(ordner, SichererName((string)anhang.FileName));
                anhang.SaveAsFile(ziel);
                pfade.Add(ziel);
            }
            catch (COMException)
            {
                // Ein Anhang, den Outlook nicht herausrückt, darf die übrigen
                // nicht mitnehmen.
            }
        }

        return pfade;
    }

    /// <summary>
    /// Das offene Nachrichtenfenster schlägt die Auswahl in der Liste: Wer eine
    /// Mail vor sich geöffnet hat, meint diese — auch wenn in der Liste
    /// dahinter noch eine andere markiert ist.
    /// </summary>
    private static dynamic? AktuelleNachricht(dynamic outlook)
    {
        try
        {
            object? inspector = outlook.ActiveInspector();
            if (inspector is not null)
            {
                dynamic offen = inspector;
                if (IstMail(offen.CurrentItem))
                {
                    return offen.CurrentItem;
                }
            }
        }
        catch (COMException)
        {
            // Kein offenes Fenster.
        }

        try
        {
            object? explorer = outlook.ActiveExplorer();
            if (explorer is null)
            {
                return null;
            }

            dynamic liste = explorer;
            dynamic auswahl = liste.Selection;
            if (auswahl.Count >= 1 && IstMail(auswahl.Item(1)))
            {
                return auswahl.Item(1);
            }
        }
        catch (COMException)
        {
            // Keine Liste, keine Auswahl.
        }

        return null;
    }

    private static bool IstMail(dynamic? element)
    {
        try
        {
            return element is not null && element.Class == OlMail;
        }
        catch (COMException)
        {
            return false;
        }
    }

    /// <summary>
    /// Eingebettete Bilder — Logos aus der Signatur des Absenders — tragen eine
    /// Content-Id. Sie als Anhang anzubieten hieße, dem Anwalt bei jeder Mail
    /// drei Grafiken vorzulegen, die niemand mitschicken will.
    /// </summary>
    private static bool IstEchteDatei(dynamic anhang)
    {
        try
        {
            if (anhang.Type != OlByValue)
            {
                return false;
            }

            var inhaltsKennung = anhang.PropertyAccessor.GetProperty(ContentIdEigenschaft) as string;
            return string.IsNullOrEmpty(inhaltsKennung);
        }
        catch (COMException)
        {
            // Keine Content-Id vorhanden: ein gewöhnlicher Anhang.
            return true;
        }
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
    /// Derselbe Anhang aus zwei Nachrichten darf sich nicht überschreiben — der
    /// zweite Griff holte sonst still den ersten Inhalt.
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
