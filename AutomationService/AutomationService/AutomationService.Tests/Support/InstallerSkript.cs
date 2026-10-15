using System.Text.RegularExpressions;

namespace AutomationService.Tests.Support;

/// <summary>
/// <c>installer/setup.iss</c>, das per <c>#include</c> eingebundene
/// <c>installer/AppLaeuft.iss</c> und der Windows-Runner der App
/// (<c>windows/runner/main.cpp</c>) als Text — für die Vertragstests (#196,
/// #199). Inno-Pascal übersetzt hier niemand; das tut ISCC im Job <c>paket</c>
/// der CI. Diese Tests halten fest, was dort stehen muss.
/// </summary>
internal static class InstallerSkript
{
    private const string Einbindung = "#include \"AppLaeuft.iss\"";

    public static string[] Setup { get; } = Lies("installer", "setup.iss");

    public static string[] AppLaeuft { get; } = Lies("installer", "AppLaeuft.iss");

    public static string[] Runner { get; } = Lies("Automation_App_Frontend", "windows", "runner", "main.cpp");

    /// <summary>
    /// Der Code, wie ISCC ihn sieht — <c>AppLaeuft.iss</c> an der Stelle seines
    /// <c>#include</c> —, ohne Kommentare und Leerzeilen.
    /// </summary>
    public static List<string> Code
    {
        get
        {
            var setup = OhneKommentare(Setup, ';');
            var stelle = setup.IndexOf(Einbindung);
            if (stelle < 0)
            {
                throw new InvalidOperationException($"setup.iss bindet AppLaeuft.iss nicht ein ({Einbindung}).");
            }

            setup.RemoveAt(stelle);
            setup.InsertRange(stelle, OhneKommentare(AppLaeuft, ';'));
            return setup;
        }
    }

    /// <summary>Die Zeilen ohne Kommentare, getrimmt — was dort steht, wirkt.</summary>
    public static List<string> OhneKommentare(string[] zeilen, char auchKommentar) => zeilen
        .Select(zeile => zeile.Trim())
        .Where(zeile => zeile.Length > 0
            && !zeile.StartsWith(auchKommentar)
            && !zeile.StartsWith("//", StringComparison.Ordinal))
        .ToList();

    /// <summary>Der Name in <c>&lt;konstante&gt; = '…';</c> (Inno) bzw. <c>&lt;konstante&gt;[] = L"…";</c> (C++).</summary>
    public static string NameIn(IEnumerable<string> zeilen, string muster)
    {
        var treffer = zeilen.Select(zeile => Regex.Match(zeile, muster)).Where(t => t.Success).ToList();
        if (treffer.Count != 1)
        {
            throw new InvalidOperationException($"Genau eine Zeile muss auf {muster} passen, es sind {treffer.Count}.");
        }

        return treffer[0].Groups[1].Value;
    }

    /// <summary>
    /// Die Zeilen nach dem Kopf einer Funktion oder Prozedur bis vor den
    /// nächsten — <paramref name="kopf"/> etwa <c>"procedure DeinitializeSetup("</c>.
    /// </summary>
    public static List<string> Rumpf(List<string> code, string kopf)
    {
        var start = code.FindIndex(zeile => zeile.StartsWith(kopf, StringComparison.Ordinal));
        if (start < 0)
        {
            throw new InvalidOperationException($"Keine Zeile beginnt mit „{kopf}“.");
        }

        var ende = code.FindIndex(start + 1, IstKopf);
        return code.GetRange(start + 1, (ende < 0 ? code.Count : ende) - start - 1);
    }

    /// <summary>Alle Funktionen und Prozeduren: Kopfzeile und Rumpf.</summary>
    public static IEnumerable<(string Kopf, List<string> Rumpf)> Routinen(List<string> code) => code
        .Where(IstKopf)
        .Select(kopf => (kopf, Rumpf(code, kopf)));

    private static bool IstKopf(string zeile) =>
        zeile.StartsWith("function ", StringComparison.Ordinal)
        || zeile.StartsWith("procedure ", StringComparison.Ordinal);

    private static string[] Lies(params string[] teile) =>
        File.ReadAllLines(Path.Combine([RepoWurzel.Pfad(), .. teile]));
}
