namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Die hochgeladene Datei ist keine lesbare SQLite-Datenbank bzw. keine gültige
/// Sicherung dieser Anwendung (z. B. fehlender Migrationsverlauf). Führt im
/// Controller zu einer 400-Antwort statt zu einem Serverfehler.
/// </summary>
public sealed class InvalidBackupException(string message, Exception? inner = null)
    : Exception(message, inner);
