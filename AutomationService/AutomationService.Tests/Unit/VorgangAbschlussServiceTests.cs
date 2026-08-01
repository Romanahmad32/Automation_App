using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft den atomaren Vorgangsabschluss (Req. 3.7 / 3.2) gegen eine echte
/// In-Memory-SQLite: Statuswechsel und Auftragsnummer hängen zusammen, doppeltes
/// Abschließen zählt nicht doppelt, unbekannte Referenzen ändern nichts.
/// </summary>
public sealed class VorgangAbschlussServiceTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangAbschlussService _service;

    public VorgangAbschlussServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _service = new VorgangAbschlussService(_db);
    }

    private async Task<VorgangEntity> LegeVorgangAn(string referenz, string status = "abgelegt")
    {
        var vorgang = new VorgangEntity
        {
            Referenz = referenz,
            AngefragtAm = new DateTime(2026, 6, 1),
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
        };
        _db.Vorgaenge.Add(vorgang);
        await _db.SaveChangesAsync();
        return vorgang;
    }

    private async Task LegeSettingsAn(int laufendeNummer)
    {
        _db.KanzleiSettings.Add(new KanzleiSettingsEntity
        {
            LaufendeAuftragsnummer = laufendeNummer,
        });
        await _db.SaveChangesAsync();
    }

    [Fact]
    public async Task Abschliessen_SetztStatusUndZaehltNummerHoch()
    {
        await LegeSettingsAn(84);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
        ergebnis.AbgeschlossenAm.Should().NotBeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(85);
    }

    [Fact]
    public async Task Abschliessen_BereitsVersendet_ZaehltNichtErneut()
    {
        await LegeSettingsAn(85);
        await LegeVorgangAn("84/26 C03_GG-XY 123", status: VorgangAbschlussService.StatusVersendet);

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(85);
    }

    [Fact]
    public async Task Abschliessen_UnbekannteReferenz_LiefertNullUndAendertNichts()
    {
        await LegeSettingsAn(84);

        var ergebnis = await _service.AbschliessenAsync("99/26 C03_XX-YY 1");

        ergebnis.Should().BeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(84);
    }

    [Fact]
    public async Task Abschliessen_OhneSettings_LegtDefaultsAnUndZaehltHoch()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        // Default ist 1, das Inkrement macht daraus 2.
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(2);
    }

    [Fact]
    public async Task Abschliessen_TrimmtDieReferenz()
    {
        await LegeSettingsAn(84);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("  84/26 C03_GG-XY 123  ");

        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
