using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Fallback-Suche für die Antwort-Zuordnung: angefragte Vorgänge
/// werden über normalisiertes Gegner-Kennzeichen + Unfalldatum gefunden —
/// tolerant gegenüber Schreibvarianten des Kennzeichens, aber strikt beim
/// Status (nur „angefragt" kommt als Zuordnungsziel infrage).
/// </summary>
public sealed class VorgangRepositoryFallbackTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangRepository _repository;

    public VorgangRepositoryFallbackTests()
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

    private async Task LegeVorgangAn(
        string referenz,
        string status = "angefragt",
        string? kennzeichen = "GG-XY 123",
        string? unfallDatum = "01.06.2026")
    {
        _db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = referenz,
            AngefragtAm = DateTime.UnixEpoch,
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
            Kennzeichen = kennzeichen,
            UnfallDatum = unfallDatum,
        });
        await _db.SaveChangesAsync();
    }

    [Fact]
    public async Task FindetAngefragtenVorgang_TolerantGegenueberKennzeichenSchreibweise()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123", kennzeichen: "gg-xy123");

        var treffer = await _repository.FindeAngefragteZuUnfallAsync("GG-XY 123", " 01.06.2026 ");

        treffer.Should().ContainSingle().Which.Referenz.Should().Be("84/26 C03_GG-XY 123");
    }

    [Fact]
    public async Task IgnoriertVorgaengeInAnderemStatus()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123", status: "beantwortet");

        (await _repository.FindeAngefragteZuUnfallAsync("GG-XY 123", "01.06.2026")).Should().BeEmpty();
    }

    [Fact]
    public async Task IgnoriertAbweichendesUnfalldatum()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        (await _repository.FindeAngefragteZuUnfallAsync("GG-XY 123", "02.06.2026")).Should().BeEmpty();
    }

    [Fact]
    public async Task LiefertAlleMehrdeutigenTreffer()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");
        await LegeVorgangAn("85/26 C03_GG-XY 123");

        (await _repository.FindeAngefragteZuUnfallAsync("GG-XY 123", "01.06.2026")).Should().HaveCount(2);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
