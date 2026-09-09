using Microsoft.Data.Sqlite;

namespace AutomationService.Features.Backup.Domain.Services;

public static class ImportDatenbank
{
    /// <summary>SQLite führt den Tausch transaktional durch; bestehende Leser behalten ihre Momentaufnahme.</summary>
    public static void Ersetze(string quelle, string ziel)
    {
        using var eingang = new SqliteConnection($"Data Source={quelle};Mode=ReadOnly;Pooling=False");
        using var ausgang = new SqliteConnection($"Data Source={ziel};Pooling=False");
        eingang.Open();
        ausgang.Open();
        eingang.BackupDatabase(ausgang);
    }
}
