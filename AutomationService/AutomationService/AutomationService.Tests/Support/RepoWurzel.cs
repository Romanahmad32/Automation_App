namespace AutomationService.Tests.Support;

/// <summary>
/// Findet die Wurzel des Repositorys (den Ordner mit Frontend, Backend und
/// docs/). Gebraucht von Tests, die Dateien ausserhalb des Dienstprojekts
/// lesen oder schreiben — etwa den versionierten HTTP-Vertrag docs/openapi.json.
/// </summary>
public static class RepoWurzel
{
    /// <exception cref="InvalidOperationException">
    /// Wenn die Wurzel nicht gefunden wird. Bewusst ein harter Fehler: ein
    /// Test, der still gruen wird, weil er die Vergleichsdatei nicht findet,
    /// meldet Erfolg fuer eine Pruefung, die nie gelaufen ist.
    /// </exception>
    public static string Pfad()
    {
        var verzeichnis = new DirectoryInfo(AppContext.BaseDirectory);
        while (verzeichnis is not null)
        {
            var hatFrontend = Directory.Exists(
                Path.Combine(verzeichnis.FullName, "Automation_App_Frontend"));
            var hatDocs = Directory.Exists(Path.Combine(verzeichnis.FullName, "docs"));
            if (hatFrontend && hatDocs)
            {
                return verzeichnis.FullName;
            }

            verzeichnis = verzeichnis.Parent;
        }

        throw new InvalidOperationException(
            $"Repository-Wurzel (Ordner mit Automation_App_Frontend/ und docs/) " +
            $"ausgehend von '{AppContext.BaseDirectory}' nicht gefunden.");
    }
}
