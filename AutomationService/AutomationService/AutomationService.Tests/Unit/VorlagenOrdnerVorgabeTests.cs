using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Vorlagenordner ist eine Einstellung (#33) — aber eine mit Rückfall: Wer
/// nie einen Ordner gewählt hat, arbeitet weiter mit dem App-Ordner unter
/// %APPDATA%. Ein falscher Rückfall hieße hier: Vorlagenliste leer, Sicherung
/// ohne Vorlagen — deshalb ausdrücklich geprüft.
/// </summary>
public sealed class VorlagenOrdnerVorgabeTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;

    public VorlagenOrdnerVorgabeTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
    }

    [Fact]
    public void OhneEinstellungszeile_FaelltAufDenAppOrdnerZurueck()
    {
        VorlagenOrdnerVorgabe.Eingestellt(_db).Should().BeEmpty();
        VorlagenOrdnerVorgabe.Ermittle(_db).Should().Be(AppDataPaths.EnsureVorlagenDirectory());
    }

    [Fact]
    public void LeererOderWeissraumWert_FaelltAufDenAppOrdnerZurueck()
    {
        SpeichereOrdner("   ");

        VorlagenOrdnerVorgabe.Eingestellt(_db).Should().BeEmpty();
        VorlagenOrdnerVorgabe.Ermittle(_db).Should().Be(AppDataPaths.EnsureVorlagenDirectory());
    }

    [Fact]
    public void GesetzterOrdner_WirdGetrimmtGeliefert()
    {
        SpeichereOrdner(@"  C:\Kanzlei\Vorlagen  ");

        VorlagenOrdnerVorgabe.Eingestellt(_db).Should().Be(@"C:\Kanzlei\Vorlagen");
        VorlagenOrdnerVorgabe.Ermittle(_db).Should().Be(@"C:\Kanzlei\Vorlagen");
    }

    private void SpeichereOrdner(string ordner)
    {
        var settings = KanzleiSettingsRepository.CreateDefault();
        settings.VorlagenOrdner = ordner;
        _db.KanzleiSettings.Add(settings);
        _db.SaveChanges();
        _db.ChangeTracker.Clear();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
