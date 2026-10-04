using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.Dtos;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Vermerk „Vollmacht gedruckt" am Vorgang (§4.11) geht über einen eigenen
/// Weg — und nur über den: Ein Upsert schickt den ganzen Vorgang aus der Sicht
/// des Aufrufers, und eine ältere Kopie ohne Vermerk nähme ihn sonst zurück.
/// </summary>
public sealed class VorgangVollmachtVermerkTests : IDisposable
{
    private const string Referenz = "84/26 C05_GG-XY 123";

    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangRepository _repository;

    public VorgangVollmachtVermerkTests()
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

    private Task<VorgangEntity> LegeAn() => _repository.UpsertAsync(new VorgangEntity
    {
        Referenz = Referenz,
        AngefragtAm = new DateTime(2026, 9, 1),
        Status = "angefragt",
        Rechtsgebiet = "Strafrecht",
    });

    [Fact]
    public async Task Der_Vermerk_laesst_sich_setzen_und_zuruecknehmen()
    {
        await LegeAn();
        var gedruckt = new DateTime(2026, 9, 13, 10, 30, 0);

        (await _repository.SetzeVollmachtGedrucktAsync(Referenz, gedruckt))!
            .VollmachtGedrucktAm.Should().Be(gedruckt);
        (await _repository.SetzeVollmachtGedrucktAsync(Referenz, null))!
            .VollmachtGedrucktAm.Should().BeNull();
    }

    [Fact]
    public async Task Ein_Upsert_ohne_Vermerk_nimmt_ihn_nicht_zurueck()
    {
        var alteKopie = await LegeAn();
        await _repository.SetzeVollmachtGedrucktAsync(Referenz, new DateTime(2026, 9, 13));

        var gespeichert = await _repository.UpsertAsync(new VorgangEntity
        {
            Referenz = Referenz,
            AngefragtAm = alteKopie.AngefragtAm,
            Status = "beantwortet",
            Rechtsgebiet = "Strafrecht",
            VollmachtGedrucktAm = null,
        });

        gespeichert.Status.Should().Be("beantwortet");
        gespeichert.VollmachtGedrucktAm.Should().Be(new DateTime(2026, 9, 13));
    }

    [Fact]
    public async Task Eine_unbekannte_Referenz_ergibt_null()
    {
        (await _repository.SetzeVollmachtGedrucktAsync("1/26 C03_XX", DateTime.Now)).Should().BeNull();
    }

    [Fact]
    public void Das_Dto_traegt_den_Vermerk_in_beide_Richtungen()
    {
        var gedruckt = new DateTime(2026, 9, 13, 9, 0, 0);
        var dto = VorgangDto.From(new VorgangEntity
        {
            Referenz = Referenz,
            Status = "angefragt",
            Rechtsgebiet = "Strafrecht",
            VollmachtGedrucktAm = gedruckt,
        });

        dto.VollmachtGedrucktAm.Should().Be(gedruckt);
        dto.ToEntity().VollmachtGedrucktAm.Should().Be(gedruckt);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
