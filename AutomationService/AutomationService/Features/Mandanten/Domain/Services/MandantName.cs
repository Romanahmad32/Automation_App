namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Die eine Regel, wann zwei Mandanten „derselbe" sind: Vor- und Nachname,
/// getrimmt und kleingeschrieben. Sie entscheidet an zwei Stellen — bei der
/// Dublettenprüfung im Register (<see cref="MandantenRepository"/>) und beim
/// Zuordnen eines Datei-Eintrags im Import (<see cref="MandantenImport"/>).
/// Zwei Fassungen davon liefen beim ersten Sonderfall auseinander, und der
/// Import legte Dubletten an, die das Register selbst abgelehnt hätte.
/// </summary>
public static class MandantName
{
    /// <summary>Vergleichsform des Namens; leer, wenn beide Teile leer sind.</summary>
    public static string Normalisiere(string? vorname, string? nachname)
    {
        var v = (vorname ?? string.Empty).Trim().ToLowerInvariant();
        var n = (nachname ?? string.Empty).Trim().ToLowerInvariant();
        return $"{v} {n}".Trim();
    }

    /// <summary>Anzeigeform „Vorname Nachname" für Meldungen.</summary>
    public static string Anzeige(string? vorname, string? nachname)
    {
        var v = (vorname ?? string.Empty).Trim();
        var n = (nachname ?? string.Empty).Trim();
        return $"{v} {n}".Trim();
    }
}
