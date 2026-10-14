using System.Collections.Concurrent;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Ein benannter Mutex, den der installierte Dienst vom Start bis zum
/// Prozessende hält (#196). <c>installer/setup.iss</c> wartet in
/// <c>InitializeSetup</c> per <c>CheckForMutexes</c>, bis es ihn nicht mehr gibt:
/// Erst dann ist die Sicherung beim Herunterfahren geschrieben, die Word-Instanz
/// des Dienstes freigegeben und keine Datei unter <c>{app}\backend</c> mehr
/// gesperrt. Inno fragt nur, ob der Mutex <i>existiert</i>; ihn zu besitzen ist
/// nicht nötig.
///
/// <b>Nie freigegeben, nie entsorgt.</b> Das Handle schließt Windows beim
/// Prozessende — genau der Zeitpunkt, den das Setup abwarten will. Ein
/// <c>Dispose</c> beim Herunterfahren des Hosts gäbe das Signal zu früh, noch
/// während die Sicherung läuft und die Programmdateien geladen sind.
/// </summary>
public static class DienstLaeuftMarke
{
    /// <summary>Steht wörtlich in <c>installer/setup.iss</c> (<c>DienstMutex</c>).</summary>
    public const string Name = "AutomationServiceLaeuft";

    private static readonly ConcurrentDictionary<string, Mutex> Gehalten = new(StringComparer.Ordinal);

    /// <summary>
    /// Nur die installierte App (Production) hält die Marke. Ein Entwicklungs-
    /// oder E2E-Testdienst auf demselben Rechner hielte sonst ein echtes Update
    /// bis zum Zeitlimit auf — und das Setup ersetzte nicht einmal seine Dateien.
    /// </summary>
    public static string? NameFuer(IHostEnvironment umgebung)
    {
        ArgumentNullException.ThrowIfNull(umgebung);
        return umgebung.IsProduction() ? Name : null;
    }

    /// <summary>
    /// Öffnet oder legt den Mutex an und hält ihn bis zum Prozessende.
    /// Mehrfacher Aufruf mit demselben Namen ist harmlos. Scheitert es, startet
    /// der Dienst trotzdem — das Setup wartet dann nicht, und der Restart
    /// Manager übernimmt wie vor #196.
    /// </summary>
    public static bool Halte(string name, ILogger logger)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentNullException.ThrowIfNull(logger);

        try
        {
            Gehalten.GetOrAdd(name, eigener => new Mutex(initiallyOwned: false, eigener));
            return true;
        }
        catch (Exception ausnahme) when (ausnahme is UnauthorizedAccessException or IOException or WaitHandleCannotBeOpenedException)
        {
            logger.LogWarning(ausnahme, "Die Marke „{Name}“ für das Setup ließ sich nicht anlegen.", name);
            return false;
        }
    }
}
