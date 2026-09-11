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
/// werden über Gegner-Kennzeichen + Unfalldatum gefunden — das Kennzeichen über
/// <c>KennzeichenVergleich</c>, tolerant gegenüber Schreibvarianten, aber strikt
/// beim Status (nur „angefragt" kommt als Zuordnungsziel infrage).
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

    /// <summary>
    /// #144: Das Backend teilte ein mehrdeutiges <c>HGE1427</c> geraten als
    /// <c>HG-E 1427</c> auf und fand den Vorgang <c>H-GE 1427</c> nicht — das
    /// Frontend schon. Treffen sich die Lesarten, ist es derselbe Wagen.
    /// </summary>
    [Fact]
    public async Task FindetAngefragtenVorgang_WennSichDieLesartenTreffen()
    {
        await LegeVorgangAn("84/26 C03_H-GE 1427", kennzeichen: "H-GE 1427");

        (await _repository.FindeAngefragteZuUnfallAsync("HGE1427", "01.06.2026")).Should().ContainSingle();
    }

    [Fact]
    public async Task FindetKeinenAnderenWagen_WennDieAufteilungGesagtIst()
    {
        await LegeVorgangAn("84/26 C03_HG-E 1427", kennzeichen: "HG-E 1427");

        (await _repository.FindeAngefragteZuUnfallAsync("H-GE 1427", "01.06.2026")).Should().BeEmpty();
    }

    /// <summary>
    /// Ein Versicherungskennzeichen liest keine Seite als Kfz-Kennzeichen — die
    /// Großschreibung darf trotzdem nicht über die Zuordnung entscheiden (#144).
    /// </summary>
    [Fact]
    public async Task FindetVersicherungskennzeichen_OhneRuecksichtAufGrossschreibung()
    {
        await LegeVorgangAn("84/26 C03_123 abc", kennzeichen: "123 abc");

        (await _repository.FindeAngefragteZuUnfallAsync("123 ABC", "01.06.2026")).Should().ContainSingle();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
