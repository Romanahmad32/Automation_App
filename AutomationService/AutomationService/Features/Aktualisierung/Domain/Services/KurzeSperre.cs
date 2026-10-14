namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Wiederholt einen Dateizugriff, den eine nur kurz gehaltene Sperre scheitern
/// lässt (#196). Ein Virenscanner prüft eine frisch geschriebene Datei und hält
/// sie dabei Sekundenbruchteile offen; ohne Wiederholung scheiterte das Update
/// an diesem Zufall, obwohl ein zweiter Versuch gleich durchginge.
///
/// Gewartet wird auf echter Zeit und bewusst nicht über einen
/// <see cref="TimeProvider"/>: Die Sperre hält das Betriebssystem, nicht die
/// Uhr, die ein Test vorstellt.
/// </summary>
public static class KurzeSperre
{
    public const int Versuche = 5;

    public static readonly TimeSpan Pause = TimeSpan.FromMilliseconds(300);

    /// <summary>Führt <paramref name="zugriff"/> aus und wiederholt ihn bei <see cref="IOException"/> und <see cref="UnauthorizedAccessException"/>.</summary>
    /// <remarks>Plattenvoll wird nicht wiederholt — das ändert sich nicht in einer Sekunde.</remarks>
    public static async Task<T> WiederholeAsync<T>(Func<T> zugriff, CancellationToken abbruch = default)
    {
        ArgumentNullException.ThrowIfNull(zugriff);

        for (var versuch = 1; ; versuch++)
        {
            try
            {
                return zugriff();
            }
            catch (Exception ausnahme) when (versuch < Versuche && IstWiederholbar(ausnahme))
            {
                await Task.Delay(Pause, abbruch);
            }
        }
    }

    private static bool IstWiederholbar(Exception ausnahme) => ausnahme switch
    {
        UnauthorizedAccessException => true,
        // ERROR_HANDLE_DISK_FULL und ERROR_DISK_FULL.
        IOException io => (io.HResult & 0xFFFF) is not (0x27 or 0x70),
        _ => false,
    };
}
