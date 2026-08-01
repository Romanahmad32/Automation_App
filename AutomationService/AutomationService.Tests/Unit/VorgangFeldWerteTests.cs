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
/// Prüft, dass die im Word-Assistenten bestätigten Formularwerte und die
/// Schadensaufstellung als opakes JSON verlustfrei durch DTO und Upsert laufen
/// (Wiederverwendung beim nächsten Schreiben desselben Vorgangs).
/// </summary>
public sealed class VorgangFeldWerteTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangRepository _repository;

    public VorgangFeldWerteTests()
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

    private static VorgangDto BaueDto(string? feldWerteJson, string? aufstellungJson) =>
        VorgangDto.From(new VorgangEntity
        {
            Referenz = "84/26 C03_GG-XY 123",
            AngefragtAm = new DateTime(2026, 6, 1),
            Status = "erstellt",
            Rechtsgebiet = "verkehrsrecht",
            FeldWerteJson = feldWerteJson,
            SchadensaufstellungJson = aufstellungJson,
        });

    [Fact]
    public void Dto_ReichtFeldWerteUndAufstellungVerlustfreiDurch()
    {
        const string feldWerte = """{"Unfallort":"Bad Homburg","Versicherer":"HUK"}""";
        const string aufstellung = """{"items":[{"description":"Reparatur","amount":1250.5}],"applyVat":true}""";

        var dto = BaueDto(feldWerte, aufstellung);
        var entity = dto.ToEntity();

        dto.FeldWerte.Should().NotBeNull();
        dto.FeldWerte!.Value.GetProperty("Unfallort").GetString().Should().Be("Bad Homburg");
        JsonDocument.Parse(entity.FeldWerteJson!).RootElement.GetProperty("Versicherer")
            .GetString().Should().Be("HUK");
        JsonDocument.Parse(entity.SchadensaufstellungJson!).RootElement.GetProperty("items")
            .GetArrayLength().Should().Be(1);
    }

    [Fact]
    public void Dto_OhneWerte_BleibtNull()
    {
        var entity = BaueDto(null, null).ToEntity();

        entity.FeldWerteJson.Should().BeNull();
        entity.SchadensaufstellungJson.Should().BeNull();
    }

    [Fact]
    public async Task Upsert_AktualisiertFeldWerteAmBestehendenVorgang()
    {
        await _repository.UpsertAsync(BaueDto(null, null).ToEntity());

        const string feldWerte = """{"Unfallort":"Bad Homburg"}""";
        await _repository.UpsertAsync(BaueDto(feldWerte, """{"items":[]}""").ToEntity());

        var gespeichert = await _db.Vorgaenge.SingleAsync();
        gespeichert.FeldWerteJson.Should().Be(feldWerte);
        gespeichert.SchadensaufstellungJson.Should().Be("""{"items":[]}""");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
