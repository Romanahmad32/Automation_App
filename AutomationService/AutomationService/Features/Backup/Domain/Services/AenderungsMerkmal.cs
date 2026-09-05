using System.Globalization;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Woran der <c>SicherungsZeitgeber</c> erkennt, ob sich seit der letzten
/// Sicherung überhaupt etwas geändert hat (§7.2, #112).
///
/// <para>
/// <b>Warum ein Fingerabdruck über die Dateien und nicht die Datenbank selbst.</b>
/// Das Issue schlägt den jüngsten <c>GeaendertAm</c>-Zeitstempel oder SQLites
/// <c>PRAGMA data_version</c> vor. Beides scheidet aus: Solche Spalten gibt es im
/// Bestand nicht (sie wären eine Schemaänderung quer durch alle Slices), und
/// <c>data_version</c> zählt nur innerhalb <em>einer</em> offenen Verbindung —
/// eine dauerhaft offene Verbindung auf die Datenbankdatei bricht aber genau das,
/// was diese Slice sonst tut: <c>DatabaseBackupService.ErsetzeDatenbankdatei</c>
/// muss die Datei beim Import austauschen können.
/// </para>
///
/// <para>
/// Länge und Änderungszeitpunkt von <c>automation.db</c> samt ihren
/// WAL-Seitendateien beantworten dieselbe Frage von außen, ohne Verbindung und
/// ohne Schema: Wird geschrieben, ändert sich mindestens eine der drei. Der
/// Fingerabdruck ist bewusst grob — er darf öfter „geändert" sagen als nötig
/// (eine Sicherung zu viel kostet nichts), aber nie „unverändert", während der
/// Anwalt gearbeitet hat.
/// </para>
/// </summary>
public static class AenderungsMerkmal
{
    /// <summary>Was SQLite im WAL-Betrieb neben der Datenbank führt.</summary>
    static readonly string[] Seitendateien = ["", "-wal", "-shm"];

    /// <summary>
    /// Der Fingerabdruck des aktuellen Standes. Wirft nie — ein unlesbarer Pfad
    /// liefert immer dieselbe Antwort (<c>?</c>) und heißt damit „unverändert":
    /// Wer den Stand nicht lesen kann, weiß nicht, ob es etwas zu sichern gibt,
    /// und sicherte sonst im Halbstundentakt ins Blaue.
    /// </summary>
    public static string Fingerabdruck(string datenbankPfad)
    {
        try
        {
            return string.Join('|', Seitendateien.Select(zusatz => Merkmal(datenbankPfad + zusatz)));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException
                                       or ArgumentException or NotSupportedException)
        {
            return "?";
        }
    }

    static string Merkmal(string pfad)
    {
        var datei = new FileInfo(pfad);

        // Die fehlende Datei ist ein eigener Wert: Ein Checkpoint, der die
        // -wal-Datei wegräumt, ist eine Änderung wie jede andere.
        return datei.Exists
            ? string.Create(CultureInfo.InvariantCulture, $"{datei.Length}@{datei.LastWriteTimeUtc.Ticks}")
            : "-";
    }
}
