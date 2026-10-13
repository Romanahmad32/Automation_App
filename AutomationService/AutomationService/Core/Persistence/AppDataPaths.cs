namespace AutomationService.Core.Persistence;

/// <summary>
/// Gemeinsame Auflösung des Anwendungs-Datenordners
/// (%APPDATA%\AutomationService). Hier liegen die SQLite-Datenbank und die
/// übrigen Laufzeitdateien (z. B. mailbox_config.json) — bewusst außerhalb des
/// Installationsverzeichnisses, damit sie ein App-Update überleben und ohne
/// Adminrechte schreibbar sind.
///
/// Umlenken lässt sich der Ordner auf zwei Wegen, und beide nie in der
/// installierten App: <see cref="WurzelFuerTests"/> für den Testlauf,
/// <see cref="Datenordner"/> für den E2E-Testmodus (#168). Vorrang hat der
/// Testlauf — so bleibt jeder <c>dotnet test</c> im Temp-Ordner, auch wenn ein
/// Test über den Host einen Datenordner hereingibt.
/// </summary>
public static class AppDataPaths
{
    /// <summary>
    /// Schlüssel der Konfiguration, oberste Ebene: <c>--Datenordner &lt;pfad&gt;</c>
    /// auf der Kommandozeile oder die Umgebungsvariable <c>Datenordner</c>.
    /// </summary>
    public const string DatenordnerSchluessel = "Datenordner";

    private static readonly Lock DatenordnerSperre = new();
    private static string? _datenordner;

    /// <summary>
    /// Nur für Tests: lenkt jeden Pfad dieser Klasse in ein anderes
    /// Wurzelverzeichnis um, statt in %APPDATA%\AutomationService. Bleibt im
    /// ausgelieferten Programm null — dort gilt immer der echte Ordner.
    /// Gesetzt wird sie genau einmal, bevor ein Test läuft (siehe
    /// <c>AutomationService.Tests.Support.TestAppDataUmgebung</c>), nie aus
    /// Produktionscode heraus.
    /// </summary>
    public static string? WurzelFuerTests { get; set; }

    /// <summary>
    /// Der konfigurierte Datenordner (#168), gesetzt in <c>Program.cs</c> vor der
    /// ersten Registrierung — <c>PersistenceInjection</c> baut den
    /// Verbindungsstring sofort. Null heißt: kein Datenordner, es gilt
    /// %APPDATA%\AutomationService.
    ///
    /// Einmal gesetzt, bleibt er: Ein zweiter, <b>anderer</b> Wert wirft. Bis
    /// dahin hat schon jemand einen Pfad aufgelöst — die Datenbank läge danach
    /// in einem Ordner, die Anhänge in einem anderen. Derselbe Wert noch einmal
    /// ist erlaubt (jeder Testhost läuft durch dieselbe Zeile).
    /// </summary>
    public static string? Datenordner
    {
        get => _datenordner;
        set
        {
            lock (DatenordnerSperre)
            {
                if (_datenordner is not null && !string.Equals(_datenordner, value, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(
                        $"Der Datenordner steht schon auf „{_datenordner}“ und lässt sich zur Laufzeit nicht umstellen.");
                }

                _datenordner = value;
            }
        }
    }

    /// <summary>
    /// True, wenn die Pfade dieser Klasse nicht nach %APPDATA% zeigen — die
    /// Bedingung, unter der der Testmodus überhaupt starten darf, und unter der
    /// der Alt-Import nie im echten Flutter-Ordner sucht.
    /// </summary>
    public static bool IstUmgelenkt =>
        WurzelFuerTests is { Length: > 0 } || Datenordner is { Length: > 0 };

    /// <summary>
    /// Liest den Datenordner aus der Konfiguration — als reine Funktion, damit
    /// sich die Regeln ohne das prozessweite Static prüfen lassen.
    ///
    /// <list type="bullet">
    /// <item>leer oder nicht gesetzt → <c>null</c>, es gilt %APPDATA%;</item>
    /// <item>in Production gesetzt → Startabbruch: Die installierte App arbeitet
    ///   immer auf den echten Daten, und eine geerbte Umgebungsvariable soll sie
    ///   nicht still auf einen leeren Bestand umsetzen;</item>
    /// <item>kein voller Pfad → Startabbruch: Relativ hinge er am
    ///   Arbeitsverzeichnis des Aufrufers, und wo die Datenbank liegt, darf
    ///   nicht davon abhängen, aus welchem Ordner gestartet wurde.</item>
    /// </list>
    /// </summary>
    public static string? DatenordnerAus(IConfiguration configuration, IHostEnvironment environment)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(environment);

        var wert = configuration[DatenordnerSchluessel];
        if (string.IsNullOrWhiteSpace(wert))
        {
            return null;
        }

        if (environment.IsProduction())
        {
            throw new InvalidOperationException(
                $"„{DatenordnerSchluessel}“ ist gesetzt ({wert}), die Umgebung ist aber Production. "
                + "Die installierte App arbeitet immer im echten Datenordner — der Dienst startet nicht. "
                + $"Für den E2E-Testmodus mit --environment E2E starten, sonst die Einstellung „{DatenordnerSchluessel}“ entfernen.");
        }

        var pfad = wert.Trim();
        if (!Path.IsPathFullyQualified(pfad))
        {
            throw new InvalidOperationException(
                $"„{DatenordnerSchluessel}“ muss ein vollständiger Pfad sein (z. B. C:\\Temp\\e2e\\daten), nicht „{pfad}“.");
        }

        return Path.GetFullPath(pfad);
    }

    /// <summary>
    /// Verzeichnis %APPDATA%\AutomationService (wird angelegt, falls nötig) —
    /// oder, umgelenkt, <see cref="WurzelFuerTests"/> vor <see cref="Datenordner"/>.
    /// </summary>
    public static string EnsureAppDataDirectory()
    {
        var directory = WurzelFuerTests is { Length: > 0 } wurzel
            ? wurzel
            : Datenordner is { Length: > 0 } datenordner
                ? datenordner
                : Path.Combine(
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

    /// <summary>
    /// Ordner für die Anhänge erfasster Postfach-Antworten (§4.3). Neben der
    /// Datenbank und nicht im Temp-Verzeichnis: Sie werden beim Versand noch
    /// gebraucht, und zwar Tage später — Windows räumt Temp ohne Vorwarnung.
    /// </summary>
    public static string EnsureAnhaengeDirectory()
    {
        var directory = Path.Combine(EnsureAppDataDirectory(), "Anhaenge");
        Directory.CreateDirectory(directory);
        return directory;
    }
}
