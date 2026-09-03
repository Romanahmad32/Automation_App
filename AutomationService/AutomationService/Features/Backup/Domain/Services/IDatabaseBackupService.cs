namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Sichert die gesamte SQLite-Datenbank in eine einzelne Datei und spielt eine
/// solche Sicherung wieder ein — gedacht für manuelle Backups und den Datenumzug
/// über App-Updates hinweg.
/// </summary>
public interface IDatabaseBackupService
{
    /// <summary>
    /// Erzeugt eine konsistente Momentaufnahme der Datenbank als eigenständige
    /// Datei und liefert deren temporären Pfad zurück. Der Aufrufer ist für das
    /// Streamen und Aufräumen der Datei verantwortlich.
    /// </summary>
    Task<string> CreateBackupFileAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Spielt eine zuvor exportierte Sicherung ein: validiert sie, sichert den
    /// aktuellen Stand vorher daneben ab, ersetzt die Datenbankdatei und hebt sie
    /// auf den aktuellen Schemastand. Wirft <see cref="InvalidBackupException"/>,
    /// wenn die Datei keine gültige Sicherung dieser Anwendung ist. Das Ergebnis
    /// nennt Vorlagen, die wegen abweichenden lokalen Inhalts nicht ersetzt wurden.
    /// </summary>
    Task<SicherungsImportErgebnis> ImportBackupAsync(
        Stream sicherung, CancellationToken cancellationToken = default);
}
