using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Unter welchem Namen ein aus Outlook geholter Anhang auf Platte landet
/// (§4.7) — und in welchem Ordner.
///
/// Eigene Datei, weil <see cref="OutlookAuswahl"/> daneben nur noch mit COM zu
/// tun hat: Wer dort die Freigabe der Verweise nachliest, soll nicht durch die
/// Namensregeln waten.
/// </summary>
internal static class OutlookAnhangNamen
{
    /// <summary>
    /// Der Ordner dieser Nachricht. Die EntryID ist stabil, taugt aber roh
    /// nicht als Ordnername — sie ist eine lange Hex-Kette. Gekuerzt und
    /// entschaerft reicht sie, um Nachrichten auseinanderzuhalten.
    /// </summary>
    public static string Ordner(dynamic nachricht)
    {
        string kennung;
        try
        {
            kennung = (string)nachricht.EntryID ?? string.Empty;
        }
        catch (COMException)
        {
            kennung = string.Empty;
        }

        var sauber = new string([.. kennung.Where(char.IsLetterOrDigit)]);
        return sauber.Length switch
        {
            0 => "Ohne-Kennung",
            > 40 => sauber[^40..],
            _ => sauber,
        };
    }

    /// <summary>Ein Dateiname, den Windows annimmt.</summary>
    public static string Sicher(string dateiname)
    {
        var name = Path.GetFileName(dateiname);
        foreach (var verboten in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(verboten, '_');
        }

        return string.IsNullOrWhiteSpace(name) ? "Anhang" : name;
    }

    /// <summary>
    /// Zwei gleichnamige Anhaenge in derselben Nachricht duerfen sich nicht
    /// ueberschreiben. Geprueft wird gegen die Namen, die dieser Griff schon
    /// vergeben hat — nicht gegen die Platte: Was vom vorigen Griff nach
    /// derselben Nachricht dort liegt, soll gerade ersetzt werden.
    /// </summary>
    public static string Frei(string ordner, string dateiname, List<string> vergeben)
    {
        var pfad = Path.Combine(ordner, dateiname);
        if (!vergeben.Contains(pfad, StringComparer.OrdinalIgnoreCase))
        {
            return pfad;
        }

        var stamm = Path.GetFileNameWithoutExtension(dateiname);
        var endung = Path.GetExtension(dateiname);
        for (var nummer = 2; ; nummer++)
        {
            pfad = Path.Combine(ordner, $"{stamm} ({nummer}){endung}");
            if (!vergeben.Contains(pfad, StringComparer.OrdinalIgnoreCase))
            {
                return pfad;
            }
        }
    }
}
