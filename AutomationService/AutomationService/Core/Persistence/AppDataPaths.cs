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

    /// <summary>
    /// Verzeichnis der Word-Vorlagen (wird angelegt, falls nötig).
    ///
    /// Bewusst hier und nicht im Installationsverzeichnis: die Vorlagen gehören
    /// dem Anwalt. Er verlinkt eigene, passt die mitgelieferten an — und ein
    /// Update, das über das Installationsverzeichnis installiert, würde genau
    /// diese Anpassungen lautlos überschreiben. Eine Deinstallation nähme sie
    /// mit. Neben der Datenbank überleben sie beides und liegen zugleich dort,
    /// wo die Sicherung sie findet.
    /// </summary>
    public static string EnsureVorlagenDirectory()
    {
        var directory = Path.Combine(EnsureAppDataDirectory(), "Vorlagen");
        Directory.CreateDirectory(directory);
        return directory;
    }
}
