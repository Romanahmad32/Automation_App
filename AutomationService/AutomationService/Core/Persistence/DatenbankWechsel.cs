using System.Collections.Concurrent;

namespace AutomationService.Core.Persistence;

/// <summary>Schützt Schreibvorgänge beim Einspielen. Alte Kontexte dürfen danach nicht speichern.</summary>
public static class DatenbankWechsel
{
    public static SemaphoreSlim Schleuse { get; } = new(1, 1);
    static readonly ConcurrentDictionary<string, long> Generationen = new(StringComparer.OrdinalIgnoreCase);
    public static AsyncLocal<(string Datenbank, long Generation)?> Auftrag { get; } = new();

    static string Schluessel(string datenbank) => string.IsNullOrEmpty(datenbank) || datenbank == ":memory:" ? ":memory:" : Path.GetFullPath(datenbank);

    public static long Generation(string datenbank) => Generationen.GetOrAdd(Schluessel(datenbank), 0);
    public static long KontextGeneration(string datenbank) => Auftrag.Value is { } auftrag
        && string.Equals(Schluessel(auftrag.Datenbank), Schluessel(datenbank), StringComparison.OrdinalIgnoreCase)
        ? auftrag.Generation : Generation(datenbank);
    public static void Vollzogen(string datenbank) => Generationen.AddOrUpdate(Schluessel(datenbank), 1, (_, bisher) => bisher + 1);

    public static void Pruefe(string datenbank, long generation)
    {
        if (generation != Generation(datenbank))
        {
            throw new InvalidOperationException(
                "Der Datenstand wurde gewechselt. Bitte die Ansicht neu laden, bevor Sie speichern.");
        }
    }
}
