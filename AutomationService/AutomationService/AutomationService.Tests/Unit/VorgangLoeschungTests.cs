using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.Sachgebiete.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;
using RegisterHistorieDienst = AutomationService.Features.RegisterHistorie.Domain.Services.RegisterHistorie;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Kopplung von Vorgang und Registerzeile beim Löschen (§6.3) gegen
/// eine echte In-Memory-SQLite: Bleibt die Zeile gewünscht, wird sie vor dem
/// Löschen des Vorgangs zu einer eigenständigen der übernommenen Historie;
/// eine Kollision des natürlichen Schlüssels bricht das Löschen nicht ab.
/// </summary>
public sealed class VorgangLoeschungTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AutomationDbContext _db;
    readonly VorgangLoeschung _loeschung;

    public VorgangLoeschungTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        var repository = new VorgangRepository(_db);
        var historie = new RegisterHistorieDienst(_db, new SachgebietKatalog(_db));
        _loeschung = new VorgangLoeschung(repository, historie);
    }

    async Task LegeVorgangAn(string referenz, int nummer, string jahr = "26", string abteilung = "C03")
    {
        _db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = referenz,
            AngefragtAm = new DateTime(2026, 1, 5),
            Status = "abgelegt",
            Rechtsgebiet = "verkehrsrecht",
            LaufendeNummer = nummer,
            Jahr = jahr,
            Abteilung = abteilung,
            MandantName = "Max Mustermann",
            Gegner = "HUK",
            UnfallDatum = "01.01.2026",
        });
        await _db.SaveChangesAsync();
    }

    [Fact]
    public async Task Loeschen_MitRegisterzeileBehalten_UebernimmtDieZeileUndLoeschtDenVorgang()
    {
        await LegeVorgangAn("5/26 C03_HG-E 1427", 5);

        var geloescht = await _loeschung.LoescheAsync("5/26 C03_HG-E 1427", registerzeileBehalten: true);

        geloescht.Should().BeTrue();
        (await _db.Vorgaenge.AnyAsync()).Should().BeFalse();
        var uebernommen = await _db.RegisterHistorie.SingleAsync();
        uebernommen.Jahr.Should().Be(2026);
        uebernommen.LaufendeNummer.Should().Be(5);
        uebernommen.NummerZusatz.Should().BeEmpty();
        uebernommen.Abteilung.Should().Be("C03");
        uebernommen.Mandant.Should().Be("Max Mustermann ./. HUK");
        uebernommen.Rechtsgebiet.Should().Be("Verkehrsrecht");
        uebernommen.Quelle.Should().Be(RegisterHistorieEntity.QuelleVorgang);
        uebernommen.Sicherheit.Should().Be(RegisterSicherheiten.Hoch);
        // Abteilung und Rechtsgebiet passen zueinander (Sachgebietskatalog),
        // die Zeile trägt also keinen Widerspruch aus der Übernahme.
        RegisterHistorieListen.Lies(uebernommen.BefundeJson).Should().BeEmpty();
    }

    [Fact]
    public async Task Loeschen_OhneRegisterzeileBehalten_LoeschtOhneZuUebernehmen()
    {
        await LegeVorgangAn("6/26 C03_HG-E 1428", 6);

        var geloescht = await _loeschung.LoescheAsync("6/26 C03_HG-E 1428", registerzeileBehalten: false);

        geloescht.Should().BeTrue();
        (await _db.Vorgaenge.AnyAsync()).Should().BeFalse();
        (await _db.RegisterHistorie.AnyAsync()).Should().BeFalse();
    }

    [Fact]
    public async Task Loeschen_UnbekannteReferenz_LiefertFalseUndAendertNichts()
    {
        var geloescht = await _loeschung.LoescheAsync("99/26 C03_XX-YY 1", registerzeileBehalten: true);

        geloescht.Should().BeFalse();
        (await _db.RegisterHistorie.AnyAsync()).Should().BeFalse();
    }

    /// <summary>
    /// Steht die Nummer schon im Register (natürlicher Schlüssel belegt),
    /// bricht das Löschen des Vorgangs trotzdem nicht ab — es gibt nur nichts
    /// mehr zu übernehmen (§6.3, siehe <see cref="IRegisterHistorie.UebernehmeAsync"/>).
    /// </summary>
    [Fact]
    public async Task Loeschen_KollisionDesSchluessels_LoeschtDenVorgangTrotzdem()
    {
        await LegeVorgangAn("7/26 C03_HG-E 1429", 7);
        _db.RegisterHistorie.Add(new RegisterHistorieEntity
        {
            Kennung = Guid.NewGuid().ToString(),
            Jahr = 2026,
            LaufendeNummer = 7,
            Aktenzeichen = "7/26",
            Abteilung = "C03",
            AbteilungRoh = "C03",
            Mandant = "Bestehende Zeile",
            Rechtsgebiet = "Verkehrsrecht",
            Sicherheit = "hoch",
            ImportiertAm = new DateTime(2020, 1, 1),
        });
        await _db.SaveChangesAsync();

        var geloescht = await _loeschung.LoescheAsync("7/26 C03_HG-E 1429", registerzeileBehalten: true);

        geloescht.Should().BeTrue();
        (await _db.Vorgaenge.AnyAsync()).Should().BeFalse();
        // Weiterhin nur die ursprüngliche Zeile — keine zweite, keine geworfene Ausnahme.
        var verbleibend = await _db.RegisterHistorie.SingleAsync();
        verbleibend.Mandant.Should().Be("Bestehende Zeile");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
