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
///
/// <b>Jeder Griff wird wieder losgelassen</b> (<see cref="ComFreigabe"/>).
/// Dieser Weg ist der heikelste: Er läuft je Entwurf mehrfach und fasst dabei
/// Explorer, Auswahl, Nachricht, Anhangsammlung und jeden einzelnen Anhang an.
/// Bliebe davon etwas liegen, hielte die App Outlook fest, nachdem der Anwalt
/// es längst geschlossen hat.
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
        // Ueber object statt dynamic hinein: Ein Aufruf mit dynamischem
        // Argument liefert wieder dynamic, und dynamic laesst sich nicht
        // zerlegen.
        var (gefunden, ausOffenemFenster) = AktuelleNachricht((object)outlook);
        if (gefunden is null)
        {
            return OutlookAnhaenge.Keine;
        }

        try
        {
            dynamic nachricht = gefunden;

            // Ein Ordner je Nachricht, benannt nach ihrer EntryID. Damit
            // liefert der zweite Griff nach derselben Mail dieselben Pfade,
            // statt "Gutachten (2).pdf" daneben zu legen: Die Oberflaeche
            // erkennt sie dann als schon geholt, und niemand muss zwei Kopien
            // einzeln wegklicken.
            var ordner = Path.Combine(
                AnhangAblage.OutlookOrdner(),
                OutlookAnhangNamen.Ordner(nachricht));
            Directory.CreateDirectory(ordner);

            return OutlookAnhaenge.Von(nachricht, Hole(nachricht, ordner), ausOffenemFenster);
        }
        finally
        {
            ComFreigabe.Gib(gefunden);
        }
    }

    /// <summary>Legt jeden echten Anhang der Nachricht in den Ordner.</summary>
    private static List<string> Hole(dynamic nachricht, string ordner)
    {
        var pfade = new List<string>();
        object sammlungGriff = nachricht.Attachments;
        try
        {
            dynamic sammlung = sammlungGriff;
            int anzahl = sammlung.Count;

            // Outlook zählt ab 1, nicht ab 0.
            for (var nummer = 1; nummer <= anzahl; nummer++)
            {
                object anhangGriff = sammlung.Item(nummer);
                try
                {
                    Speichere(anhangGriff, ordner, pfade);
                }
                finally
                {
                    ComFreigabe.Gib(anhangGriff);
                }
            }
        }
        finally
        {
            ComFreigabe.Gib(sammlungGriff);
        }

        return pfade;
    }

    private static void Speichere(object anhangGriff, string ordner, List<string> pfade)
    {
        dynamic anhang = anhangGriff;
        if (!IstEchteDatei(anhang))
        {
            return;
        }

        try
        {
            var ziel = OutlookAnhangNamen.Frei(
                ordner,
                OutlookAnhangNamen.Sicher((string)anhang.FileName),
                pfade);

            // Vom vorigen Griff nach derselben Nachricht kann die Datei noch
            // daliegen; sie soll ersetzt werden, nicht danebengelegt.
            if (File.Exists(ziel))
            {
                File.Delete(ziel);
            }

            anhang.SaveAsFile(ziel);
            pfade.Add(ziel);
        }
        catch (COMException)
        {
            // Ein Anhang, den Outlook nicht herausrückt, darf die übrigen
            // nicht mitnehmen.
        }
    }

    /// <summary>
    /// Das offene Nachrichtenfenster schlägt die Auswahl in der Liste: Wer eine
    /// Mail vor sich geöffnet hat, meint diese — auch wenn in der Liste
    /// dahinter noch eine andere markiert ist.
    /// </summary>
    /// <returns>
    /// Die Nachricht und ob sie aus einem offenen Fenster kam. Genau diese
    /// Unterscheidung geht mit zurück an die Oberfläche: Sie ist der einzige
    /// Grund, aus dem der Griff eine andere Mail erwischt als erwartet. Den
    /// zurückgegebenen Verweis gibt der Aufrufer wieder frei.
    /// </returns>
    private static (object? Nachricht, bool AusOffenemFenster) AktuelleNachricht(object anwendung)
    {
        var offen = AusFenster(anwendung);
        return offen is not null ? (offen, true) : (AusListe(anwendung), false);
    }

    private static object? AusFenster(object anwendung)
    {
        object? fenster = null;
        try
        {
            fenster = ((dynamic)anwendung).ActiveInspector();
            if (fenster is null)
            {
                return null;
            }

            object? element = ((dynamic)fenster).CurrentItem;
            if (IstMail(element))
            {
                return element;
            }

            ComFreigabe.Gib(element);
            return null;
        }
        catch (COMException)
        {
            // Kein offenes Fenster.
            return null;
        }
        finally
        {
            ComFreigabe.Gib(fenster);
        }
    }

    private static object? AusListe(object anwendung)
    {
        object? liste = null;
        object? auswahl = null;
        try
        {
            liste = ((dynamic)anwendung).ActiveExplorer();
            if (liste is null)
            {
                return null;
            }

            auswahl = ((dynamic)liste).Selection;
            dynamic markiert = auswahl;
            if (markiert.Count < 1)
            {
                return null;
            }

            object? element = markiert.Item(1);
            if (IstMail(element))
            {
                return element;
            }

            ComFreigabe.Gib(element);
            return null;
        }
        catch (COMException)
        {
            // Keine Liste, keine Auswahl.
            return null;
        }
        finally
        {
            ComFreigabe.Gib(auswahl, liste);
        }
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
        object? zugriff = null;
        try
        {
            if (anhang.Type != OlByValue)
            {
                return false;
            }

            zugriff = anhang.PropertyAccessor;
            var inhaltsKennung =
                ((dynamic)zugriff).GetProperty(ContentIdEigenschaft) as string;
            return string.IsNullOrEmpty(inhaltsKennung);
        }
        catch (COMException)
        {
            // Keine Content-Id vorhanden: ein gewöhnlicher Anhang.
            return true;
        }
        finally
        {
            ComFreigabe.Gib(zugriff);
        }
    }
}
