using AutomationService.Core.Persistence;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Wo Setup-Datei, Inno-Protokoll und Merkdatei liegen (#196):
/// <c>%LOCALAPPDATA%\AutomationService\Aktualisierung\</c>.
///
/// <b>Nicht</b> im Datenordner unter %APPDATA%: Der liegt oft in OneDrive, und
/// 85 MB Setup, die gerade geschrieben werden, wollte OneDrive hochladen —
/// womöglich mit gesperrter Datei im Moment des Starts. Und nicht im
/// Programmordner: Den ersetzt genau das Setup, das hier liegt.
///
/// Ist <see cref="AppDataPaths"/> umgelenkt (Testlauf, E2E-Testmodus), liegt
/// der Ordner unter dessen Wurzel. Sonst schriebe ein Testlauf eine Merkdatei
/// „Aktualisierung auf 9.9.9" in das Profil, und die installierte App meldete
/// beim nächsten Start ein gescheitertes Update.
/// </summary>
public sealed class AktualisierungsOrdner
{
    public const string Unterordner = "Aktualisierung";
    public const string Merkdateiname = "letzte-aktualisierung.json";
    private const string SetupPraefix = "Automation_App_Setup_";

    public AktualisierungsOrdner(string pfad)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(pfad);
        Pfad = Path.GetFullPath(pfad);
    }

    public string Pfad { get; }

    public string Merkdatei => Path.Combine(Pfad, Merkdateiname);

    /// <summary>Der Ordner für diesen Prozess; liest <see cref="AppDataPaths"/>, also erst nach Program.cs' Zuweisung aufrufen.</summary>
    public static string Vorgabe() => AppDataPaths.IstUmgelenkt
        ? Path.Combine(AppDataPaths.EnsureAppDataDirectory(), Unterordner)
        : Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "AutomationService",
            Unterordner);

    public string SetupPfad(Versionsnummer version) => Path.Combine(Pfad, $"{SetupPraefix}{version}.exe");

    public static string Teildatei(string setupPfad) => setupPfad + ".part";

    public string LogPfad(Versionsnummer version) => Path.Combine(Pfad, $"installer-{version}.log");

    /// <summary>
    /// Löscht liegengebliebene Setup- und Teildateien — außer der Setup-Datei
    /// von <paramref name="behalten"/>, solange deren Ergebnis noch nicht
    /// quittiert ist. Die Inno-Protokolle bleiben: Sie sind klein und die
    /// einzige Spur, wenn ein Update gescheitert ist.
    ///
    /// Eine gesperrte Datei (das Setup läuft noch) bleibt still liegen; der
    /// nächste Start versucht es wieder.
    /// </summary>
    public IReadOnlyList<string> RaeumeAuf(Versionsnummer? behalten, ILogger logger)
    {
        ArgumentNullException.ThrowIfNull(logger);
        if (!Directory.Exists(Pfad))
        {
            return [];
        }

        var schonen = behalten is null ? null : SetupPfad(behalten);
        var geloescht = new List<string>();
        foreach (var datei in Directory.EnumerateFiles(Pfad, $"{SetupPraefix}*"))
        {
            if (string.Equals(datei, schonen, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            try
            {
                File.Delete(datei);
                geloescht.Add(datei);
            }
            catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
            {
                logger.LogInformation(ausnahme, "Alte Setup-Datei {Datei} bleibt vorerst liegen.", datei);
            }
        }

        return geloescht;
    }
}
