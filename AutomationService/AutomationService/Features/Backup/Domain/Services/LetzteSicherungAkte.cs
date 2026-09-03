using System.Text.Json;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Hebt das Ergebnis des letzten automatischen Sicherungslaufs auf
/// (<see cref="LetzteSicherung"/>).
///
/// Liegt bewusst <em>lokal</em> neben der Datenbank und nicht in der Datenbank:
/// Ein Import ersetzt die Datenbankdatei, und dann wäre ausgerechnet die
/// Auskunft weg, ob die eigene Sicherung zuletzt gelungen ist. Und nicht im
/// Ablageordner, weil der häufigste Fehlschlag „Ablageordner nicht erreichbar"
/// heißt — eine Meldung, die man nur dort ablegen kann, wo man sie hinschreiben
/// könnte, wenn alles ginge, ist keine.
///
/// Der Pfad kommt als Zeichenkette herein statt aus <c>AppDataPaths</c>, damit
/// ein Test nicht in das echte Benutzerprofil schreibt — dasselbe Muster wie
/// beim <see cref="DatabaseBackupService"/>.
/// </summary>
public sealed class LetzteSicherungAkte(string dateipfad)
{
    static readonly JsonSerializerOptions Format = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    /// <summary>Der letzte Lauf, oder <c>null</c>, wenn es noch keinen gab.</summary>
    public LetzteSicherung? Lies()
    {
        try
        {
            return File.Exists(dateipfad)
                ? JsonSerializer.Deserialize<LetzteSicherung>(File.ReadAllText(dateipfad), Format)
                : null;
        }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException)
        {
            // Unlesbar heisst: keine Auskunft. Ein Merker darf den Start nicht
            // aufhalten — er ist die Nebensache, nicht die Hauptsache.
            return null;
        }
    }

    public void MerkeErfolg(DateTime zeitpunkt, string datei) =>
        Schreibe(new LetzteSicherung(zeitpunkt, true, datei, null, FehlerQuittiert: false));

    public void MerkeFehler(DateTime zeitpunkt, string meldung) =>
        Schreibe(new LetzteSicherung(zeitpunkt, false, null, meldung, FehlerQuittiert: false));

    /// <summary>
    /// Hält fest, dass der Anwalt den Fehlschlag gesehen hat. Der Zeitpunkt
    /// bleibt stehen — die Auskunft „zuletzt gesichert am …" soll die Quittung
    /// überleben.
    /// </summary>
    public void Quittiere()
    {
        var stand = Lies();
        if (stand is null || stand.FehlerQuittiert)
        {
            return;
        }

        Schreibe(stand with { FehlerQuittiert = true });
    }

    void Schreibe(LetzteSicherung stand)
    {
        try
        {
            var ordner = Path.GetDirectoryName(Path.GetFullPath(dateipfad));
            if (!string.IsNullOrEmpty(ordner))
            {
                Directory.CreateDirectory(ordner);
            }

            File.WriteAllText(dateipfad, JsonSerializer.Serialize(stand, Format));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Wenn schon das lokale Merken scheitert, ist der Rechner in einem
            // Zustand, den diese Datei nicht mehr rettet. Kein Grund, deshalb
            // das Herunterfahren scheitern zu lassen.
        }
    }
}
