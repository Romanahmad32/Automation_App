namespace AutomationService.Tests.Architecture;

/// <summary>
/// Zugriff auf die handgeschriebenen C#-Quelldateien des Dienstes. Grundlage
/// der Architektur-Tests: Regeln, die nur in einem Dokument stehen, gelten
/// faktisch nicht -- hier sind sie ausfuehrbar.
/// </summary>
public static class CsQuelldateien
{
    /// <summary>
    /// Verzeichnisse mit generiertem oder gebautem Code. Sie sind von allen
    /// Regeln ausgenommen: EF-Core-Migrationen erzeugt das Werkzeug, ihre
    /// Laenge und ihr Aufbau sind nicht verhandelbar.
    /// </summary>
    static readonly string[] AusgenommeneVerzeichnisse =
    [
        "/bin/", "/obj/", "/Migrations/"
    ];

    /// <summary>
    /// Wurzel des Web-Projekts (der Ordner mit AutomationService.csproj).
    /// Wird vom Ausgabeverzeichnis der Tests aus aufwaerts gesucht, weil das
    /// Arbeitsverzeichnis beim Testlauf bin/Debug/&lt;tfm&gt; ist.
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Wenn die Wurzel nicht gefunden wird. Bewusst ein harter Fehler: ein
    /// Architektur-Test, der still gruen wird, weil er nichts findet, meldet
    /// Erfolg fuer eine Pruefung, die nie gelaufen ist.
    /// </exception>
    public static string ProjektWurzel()
    {
        var verzeichnis = new DirectoryInfo(AppContext.BaseDirectory);
        while (verzeichnis is not null)
        {
            if (File.Exists(Path.Combine(verzeichnis.FullName, "AutomationService.csproj")))
            {
                return verzeichnis.FullName;
            }

            verzeichnis = verzeichnis.Parent;
        }

        throw new InvalidOperationException(
            $"Projektwurzel (Ordner mit AutomationService.csproj) ausgehend von " +
            $"'{AppContext.BaseDirectory}' nicht gefunden. Die Architektur-Tests " +
            $"koennen ohne die Quellen nicht pruefen.");
    }

    /// <summary>
    /// Alle handgeschriebenen .cs-Dateien des Dienstes, stabil sortiert fuer
    /// reproduzierbare Fehlermeldungen. Pfade sind relativ zur Projektwurzel
    /// und mit Forward-Slashes normalisiert.
    /// </summary>
    public static IReadOnlyList<Quelldatei> Alle()
    {
        var wurzel = ProjektWurzel();
        return Directory
            .EnumerateFiles(wurzel, "*.cs", SearchOption.AllDirectories)
            .Select(pfad => new Quelldatei(
                RelativerPfad(wurzel, pfad),
                pfad))
            .Where(datei => !AusgenommeneVerzeichnisse.Any(
                ausnahme => datei.RelativerPfad.Contains(ausnahme, StringComparison.Ordinal)))
            .OrderBy(datei => datei.RelativerPfad, StringComparer.Ordinal)
            .ToList();
    }

    /// <summary>
    /// Alle Quelldateien, die zu einem Feature-Slice unter Features/ gehoeren.
    /// </summary>
    public static IReadOnlyList<Quelldatei> InFeatures() =>
        Alle().Where(datei => datei.Feature is not null).ToList();

    static string RelativerPfad(string wurzel, string pfad) =>
        "/" + Path.GetRelativePath(wurzel, pfad).Replace('\\', '/');
}
