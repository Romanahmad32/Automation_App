namespace AutomationService.Core.Persistence;

/// <summary>
/// Gemeinsame Auflösung des Anwendungs-Datenordners
/// (%APPDATA%\AutomationService). Hier liegen die SQLite-Datenbank und die
/// übrigen Laufzeitdateien (z. B. mailbox_config.json) — bewusst außerhalb des
/// Installationsverzeichnisses, damit sie ein App-Update überleben und ohne
/// Adminrechte schreibbar sind.
/// </summary>
public static class AppDataPaths
{
    /// <summary>Verzeichnis %APPDATA%\AutomationService (wird angelegt, falls nötig).</summary>
    public static string EnsureAppDataDirectory()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "AutomationService");
        Directory.CreateDirectory(directory);
        return directory;
    }

    /// <summary>Vollständiger Pfad der SQLite-Datenbankdatei.</summary>
    public static string DatabaseFilePath() =>
        Path.Combine(EnsureAppDataDirectory(), "automation.db");
}
