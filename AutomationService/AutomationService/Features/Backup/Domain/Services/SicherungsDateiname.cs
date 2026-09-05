using System.Globalization;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Der Name eines automatischen Sicherungsarchivs (§7.2, #39):
/// <c>automation-&lt;Rechner&gt;-&lt;yyyyMMdd-HHmmss&gt;.zip</c>.
///
/// <para>
/// Bauen und Lesen stehen bewusst in <em>einer</em> Klasse. Der Zeitpunkt im
/// Namen ist die einzige verlässliche Auskunft über das Alter eines Archivs: Das
/// Änderungsdatum der Datei setzt der Synchronisierungsdienst beim Herunterladen
/// neu, und die <see cref="Aufbewahrungsregel"/> löschte am zweiten Rechner dann
/// die falschen. Wer den Namen baut, ohne den Leser danebenzustellen, bricht
/// genau diese Kette.
/// </para>
/// </summary>
public static class SicherungsDateiname
{
    /// <summary>Sortierbar und frei von Zeichen, die in einem Dateinamen stören.</summary>
    public const string Zeitformat = "yyyyMMdd-HHmmss";

    const string Praefix = "automation-";
    const string Endung = ".zip";

    /// <summary>Der Name, unter dem eine neue Sicherung abgelegt wird.</summary>
    public static string Baue(string rechnername, DateTime zeitpunkt) =>
        Anfang(rechnername)
        + zeitpunkt.ToString(Zeitformat, CultureInfo.InvariantCulture)
        + Endung;

    /// <summary>Alle Archive dieses Rechners — und ausdrücklich nur seine.</summary>
    public static string Suchmuster(string rechnername) => Anfang(rechnername) + "*" + Endung;

    /// <summary>
    /// Der Zeitpunkt aus einem Dateinamen (ohne Pfad), oder <c>null</c>, wenn der
    /// Name keiner ist, den dieser Rechner geschrieben hat.
    ///
    /// <para>
    /// <b>Warum das streng ist.</b> Was hier durchkommt, darf aufgeräumt werden.
    /// Eine vom Anwalt umbenannte Datei („… – Kopie.zip"), eine Konfliktkopie des
    /// Synchronisierers, ein unmögliches Datum (Tag 00) und das Archiv eines
    /// Rechners, dessen Name mit dem eigenen beginnt (BUERO neben BUERO-2), sind
    /// deshalb <em>kein</em> Treffer: Der Name muss der gebaute sein, Zeichen für
    /// Zeichen. Das Suchmuster allein leistet das nicht — <c>automation-BUERO-*</c>
    /// findet auch die Archive von BUERO-2.
    /// </para>
    /// </summary>
    public static DateTime? Zeitpunkt(string dateiname, string rechnername)
    {
        var anfang = Anfang(rechnername);
        if (dateiname is null
            || dateiname.Length != anfang.Length + Zeitformat.Length + Endung.Length
            || !dateiname.StartsWith(anfang, StringComparison.OrdinalIgnoreCase)
            || !dateiname.EndsWith(Endung, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return DateTime.TryParseExact(
            dateiname[anfang.Length..^Endung.Length],
            Zeitformat,
            CultureInfo.InvariantCulture,
            DateTimeStyles.None,
            out var zeitpunkt)
            ? zeitpunkt
            : null;
    }

    static string Anfang(string rechnername) => $"{Praefix}{rechnername}-";
}
