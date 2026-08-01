using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Referenzänderung (Referenz korrigieren) gegen eine echte
/// In-Memory-SQLite: Umbenennen aktualisiert die Bestandteile, belegte
/// Zielreferenzen werden abgewiesen, unbekannte Ausgangsreferenzen ändern nichts.
/// </summary>
public sealed class VorgangRepositoryReferenzTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangRepository _repository;

    public VorgangRepositoryReferenzTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _repository = new VorgangRepository(_db);
    }

    private async Task<VorgangEntity> LegeVorgangAn(string referenz)
    {
        var vorgang = new VorgangEntity
        {
            Referenz = referenz,
            AngefragtAm = new DateTime(2026, 6, 1),
            Status = "angefragt",
            Rechtsgebiet = "verkehrsrecht",
            AntwortJson = """{"versichererName":"HUK"}""",
        };
        _db.Vorgaenge.Add(vorgang);
        await _db.SaveChangesAsync();
        return vorgang;
    }

    [Fact]
    public async Task Rename_AktualisiertReferenzUndBestandteile()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _repository.RenameReferenzAsync(
            "84/26 C03_GG-XY 123", "85/26 C04_HG-E 1427");

        ergebnis.Status.Should().Be(ReferenzAenderungStatus.Geaendert);
        var gespeichert = await _db.Vorgaenge.SingleAsync();
        gespeichert.Referenz.Should().Be("85/26 C04_HG-E 1427");
        gespeichert.LaufendeNummer.Should().Be(85);
        gespeichert.Jahr.Should().Be("26");
        gespeichert.Abteilung.Should().Be("C04");
        gespeichert.Kennzeichen.Should().Be("HG-E 1427");
        // Übrige Vorgangsdaten bleiben unangetastet.
        gespeichert.AntwortJson.Should().Contain("HUK");
    }

    [Fact]
    public async Task Rename_ZielreferenzVergeben_WirdAbgewiesen()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");
        await LegeVorgangAn("85/26 C03_HG-E 1427");

        var ergebnis = await _repository.RenameReferenzAsync(
            "84/26 C03_GG-XY 123", "85/26 c03_hg-e 1427");

        ergebnis.Status.Should().Be(ReferenzAenderungStatus.Vergeben);
        (await _db.Vorgaenge.CountAsync(v => v.Referenz == "84/26 C03_GG-XY 123")).Should().Be(1);
    }

    [Fact]
    public async Task Rename_UnbekannteAusgangsreferenz_LiefertNichtGefunden()
    {
        var ergebnis = await _repository.RenameReferenzAsync(
            "99/26 C03_XX-YY 1", "85/26 C03_HG-E 1427");

        ergebnis.Status.Should().Be(ReferenzAenderungStatus.NichtGefunden);
    }

    [Fact]
    public async Task Rename_GleicheReferenz_IstNoOp()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _repository.RenameReferenzAsync(
            "84/26 C03_GG-XY 123", "  84/26 C03_GG-XY 123  ");

        ergebnis.Status.Should().Be(ReferenzAenderungStatus.Geaendert);
        ergebnis.Vorgang!.Referenz.Should().Be("84/26 C03_GG-XY 123");
    }

    [Fact]
    public async Task Rename_ReferenzAusserhalbDesSchemas_LeertBestandteile()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _repository.RenameReferenzAsync(
            "84/26 C03_GG-XY 123", "Sonderfall Mueller");

        ergebnis.Status.Should().Be(ReferenzAenderungStatus.Geaendert);
        var gespeichert = await _db.Vorgaenge.SingleAsync();
        gespeichert.Referenz.Should().Be("Sonderfall Mueller");
        gespeichert.LaufendeNummer.Should().BeNull();
        gespeichert.Jahr.Should().BeNull();
        gespeichert.Abteilung.Should().BeNull();
        gespeichert.Kennzeichen.Should().BeNull();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
