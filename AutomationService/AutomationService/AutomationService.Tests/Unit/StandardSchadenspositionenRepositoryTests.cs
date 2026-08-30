using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sichert die Zusagen der Standardpositionen (§4.4): Ohne Konfiguration
/// kommt die Vorgabe aus dem Code, gespeichert wird als Komplettersatz in der
/// übergebenen Reihenfolge, und die leere Liste ist das Zurücksetzen — nicht
/// eine Konfiguration aus nichts.
/// </summary>
public sealed class StandardSchadenspositionenRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly StandardSchadenspositionenRepository _repository;

    public StandardSchadenspositionenRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _repository = new StandardSchadenspositionenRepository(_db);
    }

    [Fact]
    public async Task GetAsync_OhneKonfiguration_LiefertDieVorgabeOhneBetraege()
    {
        var positionen = await _repository.GetAsync();

        positionen.Select(p => p.Bezeichnung)
            .Should().Equal(StandardSchadenspositionenVorgabe.Bezeichnungen);
        positionen.Should().OnlyContain(p => p.Betrag == null);
    }

    [Fact]
    public async Task SaveAsync_ErsetztDieListe_UndBehaeltDieReihenfolge()
    {
        await _repository.SaveAsync(
        [
            new StandardSchadenspositionEntity { Bezeichnung = "Mietwagenkosten", Betrag = 412.50m },
            new StandardSchadenspositionEntity { Bezeichnung = "  Unkostenpauschale  ", Betrag = 30m },
        ]);
        _db.ChangeTracker.Clear();

        var gelesen = await _repository.GetAsync();
        gelesen.Select(p => (p.Bezeichnung, p.Betrag)).Should().Equal(
            ("Mietwagenkosten", 412.50m),
            ("Unkostenpauschale", 30m));
    }

    [Fact]
    public async Task SaveAsync_MitLeererListe_SetztAufDieVorgabeZurueck()
    {
        await _repository.SaveAsync(
            [new StandardSchadenspositionEntity { Bezeichnung = "Mietwagenkosten" }]);
        _db.ChangeTracker.Clear();

        var zurueckgesetzt = await _repository.SaveAsync([]);

        zurueckgesetzt.Select(p => p.Bezeichnung)
            .Should().Equal(StandardSchadenspositionenVorgabe.Bezeichnungen);
    }

    /// <summary>
    /// Eine Zeile ohne Bezeichnung ist keine Position — sonst wäre eine Liste
    /// aus lauter Leerzeilen eine Konfiguration statt eines Zurücksetzens.
    /// </summary>
    [Fact]
    public async Task SaveAsync_VerwirftZeilenOhneBezeichnung()
    {
        var gespeichert = await _repository.SaveAsync(
        [
            new StandardSchadenspositionEntity { Bezeichnung = "   " },
            new StandardSchadenspositionEntity { Bezeichnung = "Sachverständigenkosten" },
        ]);

        gespeichert.Select(p => p.Bezeichnung).Should().Equal("Sachverständigenkosten");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
