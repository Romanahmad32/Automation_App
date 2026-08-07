using Microsoft.Data.Sqlite;

namespace AutomationService.Core.Persistence;

/// <summary>
/// Gemeinsames Kopieren einer SQLite-Datenbankdatei.
///
/// <c>VACUUM INTO</c> statt eines rohen File.Copy: im WAL-Betrieb steht ein Teil
/// der Daten in der -wal-Datei, eine reine Kopie der .db waere also unvollstaendig
/// bis unbrauchbar. VACUUM INTO schreibt stattdessen eine in sich stimmige
/// Einzeldatei ohne Seitendateien — und das auch, waehrend die Datenbank in
/// Benutzung ist.
///
/// Liegt im Kern und nicht im Backup-Slice, weil es zwei Aufrufer gibt: die
/// Sicherung auf Wunsch des Anwenders und die automatische Sicherung vor einer
/// Schema-Migration.
/// </summary>
public static class SqliteSicherung
{
    /// <summary>Schreibt eine konsistente Kopie von <paramref name="quellPfad"/> nach <paramref name="zielPfad"/>.</summary>
    public static async Task VacuumIntoAsync(
        string quellPfad,
        string zielPfad,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqliteConnection($"Data Source={quellPfad}");
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        // VACUUM INTO akzeptiert keinen gebundenen Parameter fuer den Dateinamen;
        // das Hochkomma wird deshalb nach SQL-Konvention verdoppelt.
        command.CommandText = $"VACUUM main INTO '{zielPfad.Replace("'", "''", StringComparison.Ordinal)}';";
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>
    /// Loescht die aeltesten Sicherungen und behaelt die <paramref name="behalte"/>
    /// neuesten. Ohne das waechst der Ordner mit jedem Update weiter — bei einer
    /// Datenbank in dieser Groessenordnung unauffaellig, aber unnoetig.
    /// </summary>
    public static void RaeumeAelteSicherungenAuf(string verzeichnis, string suchmuster, int behalte)
    {
        try
        {
            var dateien = new DirectoryInfo(verzeichnis)
                .GetFiles(suchmuster)
                .OrderByDescending(datei => datei.CreationTimeUtc)
                .Skip(behalte);

            foreach (var datei in dateien)
            {
                datei.Delete();
            }
        }
        catch (IOException)
        {
            // Aufraeumen ist Kuer. Scheitert es, bleibt eine Datei zu viel liegen —
            // kein Grund, den Start der Anwendung zu gefaehrden.
        }
        catch (UnauthorizedAccessException)
        {
            // dito
        }
    }
}
