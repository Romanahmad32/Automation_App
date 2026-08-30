using System.Text.Json;
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
/// Der angefangene Ausfüllstand (§4.4) liegt getrennt von den bestätigten
/// Formularwerten und wird über einen eigenen Weg geschrieben — beim Tippen
/// laufend. Genau deshalb darf er nichts anderes anfassen: Ein Upsert des ganzen
/// Vorgangs würde bei jedem Tastendruck-Intervall auch die Spalten
/// überschreiben, die der Aufrufer nur als Kopie kennt (eine inzwischen
/// eingetroffene Zentralruf-Antwort etwa).
/// </summary>
public sealed class VorgangEntwurfTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangRepository _repository;

    private const string Referenz = "84/26 C03_GG-XY 123";
    private const string Entwurf =
        """{"gespeichertAm":"2026-08-30T14:32:00.000","feldWerte":{"Versicherer":"HUK"}}""";

    public VorgangEntwurfTests()
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

    private async Task<VorgangEntity> LegeAn() => await _repository.UpsertAsync(new VorgangEntity
    {
        Referenz = Referenz,
        AngefragtAm = new DateTime(2026, 6, 1),
        Status = "beantwortet",
        Rechtsgebiet = "verkehrsrecht",
        FeldWerteJson = """{"Versicherer":"Allianz"}""",
        AntwortJson = """{"versichererName":"HUK-COBURG"}""",
    });

    [Fact]
    public void Dto_ReichtDenEntwurfVerlustfreiDurch()
    {
        var dto = VorgangDto.From(new VorgangEntity
        {
            Referenz = Referenz,
            AngefragtAm = new DateTime(2026, 6, 1),
            Status = "angefragt",
            Rechtsgebiet = "verkehrsrecht",
            EntwurfJson = Entwurf,
        });

        dto.Entwurf.Should().NotBeNull();
        dto.Entwurf!.Value.GetProperty("feldWerte").GetProperty("Versicherer")
            .GetString().Should().Be("HUK");
        JsonDocument.Parse(dto.ToEntity().EntwurfJson!).RootElement
            .GetProperty("gespeichertAm").GetString().Should().Be("2026-08-30T14:32:00.000");
    }

    [Fact]
    public async Task SetzeEntwurf_LaesstBestaetigtesUndAntwortUnberuehrt()
    {
        await LegeAn();

        var gespeichert = await _repository.SetzeEntwurfAsync(Referenz, Entwurf);

        gespeichert!.EntwurfJson.Should().Be(Entwurf);
        gespeichert.FeldWerteJson.Should().Be("""{"Versicherer":"Allianz"}""");
        gespeichert.AntwortJson.Should().Be("""{"versichererName":"HUK-COBURG"}""");
        gespeichert.Status.Should().Be("beantwortet");
    }

    [Fact]
    public async Task SetzeEntwurf_MitNull_VerwirftNurDenEntwurf()
    {
        await LegeAn();
        await _repository.SetzeEntwurfAsync(Referenz, Entwurf);

        var gespeichert = await _repository.SetzeEntwurfAsync(Referenz, null);

        gespeichert!.EntwurfJson.Should().BeNull();
        gespeichert.FeldWerteJson.Should().Be("""{"Versicherer":"Allianz"}""");
    }

    [Fact]
    public async Task SetzeEntwurf_OhneVorgang_MeldetNichtGefunden()
    {
        var ergebnis = await _repository.SetzeEntwurfAsync("gibt/es 00_nicht", Entwurf);

        ergebnis.Should().BeNull();
    }

    /// <summary>
    /// Die Referenz kommt aus einem Query-Parameter und trägt gern Leerzeichen
    /// vom Umbruch einer Mail — sie wird wie überall sonst bereinigt verglichen.
    /// </summary>
    [Fact]
    public async Task SetzeEntwurf_FindetDenVorgangAuchMitRandLeerzeichen()
    {
        await LegeAn();

        var gespeichert = await _repository.SetzeEntwurfAsync($"  {Referenz}  ", Entwurf);

        gespeichert.Should().NotBeNull();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
