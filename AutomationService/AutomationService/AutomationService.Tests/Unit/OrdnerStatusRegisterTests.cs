using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Vermerke „ohne Mandantenbezug" gegen eine echte In-Memory-SQLite.
/// Der Zuordnungsstapel soll auf null gehen können, ohne dass etwas still
/// verschwindet — deshalb ist jede Entscheidung eine Zeile und jede
/// zurücknehmbar.
/// </summary>
public sealed class OrdnerStatusRegisterTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly OrdnerStatusRegister _register;

    public OrdnerStatusRegisterTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _register = new OrdnerStatusRegister(_db);
    }

    [Fact]
    public async Task SetzeAsync_MarkiertMehrereOrdnerAufEinmal()
    {
        var stand = await _register.SetzeAsync(
            ["Bussgeldsache Saeed", "FamSache Mark"],
            OrdnerStatusArten.OhneMandantenbezug);

        stand.Should().HaveCount(2);
        stand.Select(o => o.Ordnername)
            .Should().BeEquivalentTo("Bussgeldsache Saeed", "FamSache Mark");
        stand.Should().OnlyContain(o => o.Status == OrdnerStatusArten.OhneMandantenbezug);
        stand.Should().OnlyContain(o => o.GesetztAm != default);
    }

    [Fact]
    public async Task SetzeAsync_MitNullNimmtDenVermerkZurueck()
    {
        await _register.SetzeAsync(
            ["Bussgeldsache Saeed", "FamSache Mark"],
            OrdnerStatusArten.OhneMandantenbezug);

        var stand = await _register.SetzeAsync(["FamSache Mark"], status: null);

        stand.Should().ContainSingle().Which.Ordnername.Should().Be("Bussgeldsache Saeed");
    }

    // Der Ordnername ist der fachliche Schluessel: zweimal dieselbe
    // Entscheidung darf keine zweite Zeile ergeben.
    [Fact]
    public async Task SetzeAsync_IstFuerDenselbenOrdnerIdempotent()
    {
        await _register.SetzeAsync(["Strafsache Mark"], OrdnerStatusArten.OhneMandantenbezug);
        var stand = await _register.SetzeAsync(["Strafsache Mark"], OrdnerStatusArten.OhneMandantenbezug);

        stand.Should().ContainSingle();
    }

    [Fact]
    public async Task SetzeAsync_UebergehtLeereNamen()
    {
        var stand = await _register.SetzeAsync(
            ["", "   ", "Owi Peter"],
            OrdnerStatusArten.OhneMandantenbezug);

        stand.Should().ContainSingle().Which.Ordnername.Should().Be("Owi Peter");
    }

    // Ordnernamen kommen aus dem Windows-Dateisystem, und das kennt
    // "VUnfallursache Mark" und "vunfallursache mark" nicht als zwei Ordner.
    // Binaer verglichen bekaeme derselbe Ordner zwei Zeilen, und das
    // Zuruecknehmen ueber die andere Schreibweise fuende seine nicht.
    [Fact]
    public async Task SetzeAsync_VergleichtOrdnernamenOhneGrossKleinschreibung()
    {
        await _register.SetzeAsync(
            ["VUnfallursache Mark"], OrdnerStatusArten.OhneMandantenbezug);

        var nochmal = await _register.SetzeAsync(
            ["vunfallursache mark"], OrdnerStatusArten.OhneMandantenbezug);

        nochmal.Should().ContainSingle()
            .Which.Ordnername.Should().Be("VUnfallursache Mark",
                "die vorhandene Zeile behaelt ihre Schreibweise");
    }

    [Fact]
    public async Task SetzeAsync_NimmtDenVermerkAuchBeiAndererSchreibweiseZurueck()
    {
        await _register.SetzeAsync(
            ["VUnfallursache Mark"], OrdnerStatusArten.OhneMandantenbezug);

        var stand = await _register.SetzeAsync(["VUNFALLURSACHE MARK"], status: null);

        stand.Should().BeEmpty();
    }

    [Fact]
    public async Task SetzeAsync_WeistUnbekanntenStatusAb()
    {
        var aufruf = () => _register.SetzeAsync(["Owi Peter"], "erledigt");

        await aufruf.Should().ThrowAsync<ArgumentException>();
        (await _register.GetAllAsync()).Should().BeEmpty();
    }

    [Fact]
    public async Task GetAllAsync_LiefertNachOrdnernameSortiert()
    {
        await _register.SetzeAsync(
            ["Strafsache Zeta", "Bussgeldsache Alpha"],
            OrdnerStatusArten.OhneMandantenbezug);

        var stand = await _register.GetAllAsync();

        stand.Select(o => o.Ordnername)
            .Should().ContainInOrder("Bussgeldsache Alpha", "Strafsache Zeta");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
