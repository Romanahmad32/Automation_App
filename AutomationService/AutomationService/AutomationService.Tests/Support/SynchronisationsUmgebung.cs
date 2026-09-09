using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace AutomationService.Tests.Support;

public sealed class SynchronisationsUmgebung : IDisposable
{
    public string Wurzel { get; } = Path.Combine(Path.GetTempPath(), "sync-test-" + Guid.NewGuid().ToString("N"));
    public string Datenbank => Path.Combine(Wurzel, "automation.db");
    public string Vorlagen => Path.Combine(Wurzel, "Vorlagen");
    public string Ablage => Path.Combine(Wurzel, "OneDrive", "Sicherungen");
    public DatabaseBackupService Sicherung { get; }
    public AutomatischeSicherung Automatik { get; }
    public ArbeitsplatzUebergabe Uebergabe { get; }

    public SynchronisationsUmgebung()
    {
        Directory.CreateDirectory(Vorlagen);
        Directory.CreateDirectory(Ablage);
        Sicherung = new(Datenbank, () => Vorlagen, NullLogger<DatabaseBackupService>.Instance);
        var merker = new LetzteSicherungAkte(Path.Combine(Wurzel, "letzte.json"));
        Automatik = new(Sicherung, merker, () => Ablage, NullLogger<AutomatischeSicherung>.Instance);
        Uebergabe = new(Sicherung, merker, () => Ablage, NullLogger<ArbeitsplatzUebergabe>.Instance);
    }

    public AutomationDbContext Kontext() => new(new DbContextOptionsBuilder<AutomationDbContext>()
        .UseSqlite($"Data Source={Datenbank}").Options);

    public async Task Initialisiere()
    {
        await using var db = Kontext();
        await db.Database.MigrateAsync();
    }

    public async Task Mandant(string name)
    {
        await using var db = Kontext();
        db.Mandanten.Add(new MandantEntity { Nachname = name });
        await db.SaveChangesAsync();
    }

    public async Task<ArbeitsplatzEintrag> FremderStand(bool nachfolger = true, int stunden = 1)
    {
        var lokal = Sicherung.Verlauf.Lies()?.Eintrag;
        var archiv = await Sicherung.CreateBackupFileAsync();
        var name = $"automation-LAPTOP-{Guid.NewGuid():N}.zip";
        File.Move(archiv, Path.Combine(Ablage, name));
        using var strom = File.OpenRead(Path.Combine(Ablage, name));
        var eintrag = new ArbeitsplatzEintrag("LAPTOP", DateTime.Now.AddHours(stunden), DateTime.Now.AddHours(stunden), name, "1.0")
        {
            Revision = Guid.NewGuid().ToString("N"),
            Vorfahren = nachfolger && lokal?.Revision is { } revision ? [.. lokal.Vorfahren, revision] : [],
            Bytes = strom.Length,
            Sha256 = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(strom)),
        };
        ArbeitsplatzAkte.Schreibe(Ablage, eintrag);
        return eintrag;
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        Directory.Delete(Wurzel, recursive: true);
    }
}
