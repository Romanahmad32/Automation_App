using System.Text.Json;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>Inhalt der Merkdatei: worauf aktualisiert werden sollte, und wann.</summary>
public sealed record Merkzettel(string ZielVersion, DateTimeOffset Zeitpunkt);

/// <summary>
/// Die Merkdatei einer begonnenen Aktualisierung (#196). Geschrieben, bevor der
/// Installer startet; gelesen beim nächsten Start des Dienstes. Daran erkennt
/// die App, ob das Update auf X geklappt hat — und meldet ein gescheitertes,
/// statt nur wieder „Update verfügbar" zu zeigen und den Anwender in eine
/// Schleife zu schicken.
///
/// Gelöscht wird sie erst, wenn das Frontend das Ergebnis einmal gezeigt hat
/// (<c>POST api/Aktualisierung/ergebnis-quittieren</c>).
/// </summary>
public sealed class Merkdatei(string pfad)
{
    private static readonly JsonSerializerOptions Format = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    /// <summary>Der Zettel, oder <c>null</c>, wenn es keinen gibt oder er unlesbar ist.</summary>
    public Merkzettel? Lies()
    {
        try
        {
            return File.Exists(pfad)
                ? JsonSerializer.Deserialize<Merkzettel>(File.ReadAllText(pfad), Format)
                : null;
        }
        catch (Exception ausnahme) when (ausnahme is JsonException or IOException or UnauthorizedAccessException)
        {
            // Unlesbar heißt: keine Auskunft. Ein Merker darf den Start nicht aufhalten.
            return null;
        }
    }

    /// <summary>
    /// Was der Zettel beim Start über die letzte Aktualisierung sagt: erfolgreich,
    /// wenn die laufende Version mindestens die Zielversion ist. Ohne Zettel
    /// <c>null</c>; ein unlesbarer wird gelöscht — er hat nichts zu berichten.
    /// </summary>
    public LetzteAktualisierung? Auswerten(string laufendeVersion)
    {
        var ziel = Versionsnummer.Lies(Lies()?.ZielVersion);
        if (ziel is null)
        {
            Loesche();
            return null;
        }

        var laufend = Versionsnummer.Lies(laufendeVersion);
        return new LetzteAktualisierung(ziel.ToString(), laufend is not null && !ziel.IstHoeherAls(laufend));
    }

    /// <summary>
    /// Schreibt atomar (erst daneben, dann umbenennen): Bricht der Dienst
    /// mittendrin ab, liegt ein alter oder gar kein Zettel da, nie ein halber.
    /// Wirft, wenn das nicht geht — dann startet auch kein Installer.
    /// </summary>
    public void Schreibe(Merkzettel zettel)
    {
        var ordner = Path.GetDirectoryName(Path.GetFullPath(pfad));
        if (!string.IsNullOrEmpty(ordner))
        {
            Directory.CreateDirectory(ordner);
        }

        var neu = pfad + ".neu";
        File.WriteAllText(neu, JsonSerializer.Serialize(zettel, Format));
        File.Move(neu, pfad, overwrite: true);
    }

    public void Loesche()
    {
        try
        {
            File.Delete(pfad);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            // Bleibt sie liegen, meldet der nächste Start dasselbe Ergebnis
            // noch einmal — lästig, aber nicht falsch.
        }
    }
}
