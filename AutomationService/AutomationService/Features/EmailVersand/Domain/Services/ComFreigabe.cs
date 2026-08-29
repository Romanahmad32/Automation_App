using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Lässt Outlook-Objekte wieder los (§4.7).
///
/// Jeder Griff über Late Binding — <c>Attachments</c>, <c>Item(1)</c>,
/// <c>GetInspector</c>, <c>Selection</c> — erzeugt einen eigenen Verweis auf
/// ein Objekt in outlook.exe. Solange dieser Verweis im Referenzzähler steht,
/// hält er das Programm fest: Der Anwalt schliesst Outlook, das Fenster
/// verschwindet, der Prozess bleibt. Bei einer App, die den Griff über Stunden
/// wiederholt, sammeln sich diese Verweise an — dieselbe Vorsorge trifft
/// <c>WordInteropPdfConversionService</c> gegen den WINWORD-Zombie.
///
/// Der Garbage Collector räumt sie zwar irgendwann von selbst weg.
/// „Irgendwann" ist aber genau das, was den Zombie-Prozess ausmacht.
///
/// Freigegeben wird auf dem Thread, der den Verweis geholt hat — dem STA-Thread
/// von <see cref="OutlookVerbindung"/>.
/// </summary>
internal static class ComFreigabe
{
    /// <summary>
    /// Gibt die Verweise in der Reihenfolge der Argumente frei; gedacht ist sie
    /// von innen nach aussen. Null und alles, was gar kein COM-Objekt ist,
    /// wird übergangen — der Aufrufer soll nicht prüfen müssen, ob überhaupt
    /// etwas zu tun ist.
    /// </summary>
    public static void Gib(params object?[] verweise)
    {
        foreach (var verweis in verweise)
        {
            Einzeln(verweis);
        }
    }

    private static void Einzeln(object? verweis)
    {
        if (verweis is null)
        {
            return;
        }

        try
        {
            if (Marshal.IsComObject(verweis))
            {
                Marshal.ReleaseComObject(verweis);
            }
        }
        catch (Exception ausnahme)
            when (ausnahme is ArgumentException or InvalidComObjectException)
        {
            // Bereits freigegeben oder nie ein lebendiger Verweis gewesen. Beim
            // Aufräumen ist das kein Grund zu scheitern: Der Zweck — das
            // Objekt nicht mehr festzuhalten — ist dann ohnehin erreicht.
        }
    }
}
