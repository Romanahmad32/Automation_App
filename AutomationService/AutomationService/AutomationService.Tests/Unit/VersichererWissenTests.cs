using AutomationService.Core.Persistence;
using AutomationService.Features.Versicherer.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Versicherer-Wissensbasis gegen eine echte In-Memory-SQLite:
/// automatisches Lernen aus Antworten mit Dedupe über den normalisierten Namen,
/// „neuere Antwort gewinnt" für gefüllte Felder — aber leere Antwortfelder
/// löschen nie bereits gelerntes Wissen.
/// </summary>
public sealed class VersichererWissenTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VersichererWissen _wissen;

    public VersichererWissenTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _wissen = new VersichererWissen(_db);
    }

    [Fact]
    public async Task MerkeAusAntwort_NeuerVersicherer_WirdVollstaendigAngelegt()
    {
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData
        {
            VersichererName = "HUK-COBURG",
            VersichererStrasse = "Bahnhofsplatz 1",
            VersichererPlz = "96444",
            VersichererOrt = "Coburg",
            VersichererEmail = "schaden@huk.de",
            AnfrageDatum = "12.06.2026",
        });

        var eintrag = await _db.Versicherer.SingleAsync();
        eintrag.Name.Should().Be("HUK-COBURG");
        eintrag.NameNormalisiert.Should().Be("HUK-COBURG");
        eintrag.Strasse.Should().Be("Bahnhofsplatz 1");
        eintrag.Email.Should().Be("schaden@huk.de");
        eintrag.Quelle.Should().Contain("12.06.2026");
    }

    [Fact]
    public async Task MerkeAusAntwort_SchreibvarianteDesNamens_ErzeugtKeinenZweitenEintrag()
    {
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData { VersichererName = "HUK-COBURG" });
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData { VersichererName = "  huk-coburg  " });

        (await _db.Versicherer.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task MerkeAusAntwort_NeuererWertGewinnt_LeeresFeldLoeschtNichts()
    {
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData
        {
            VersichererName = "HUK-COBURG",
            VersichererOrt = "Coburg",
            VersichererEmail = "schaden@huk.de",
        });

        // Spätere Antwort ohne E-Mail, aber mit neuer Anschrift.
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData
        {
            VersichererName = "HUK-COBURG",
            VersichererOrt = "Köln",
        });

        var eintrag = await _db.Versicherer.SingleAsync();
        eintrag.Ort.Should().Be("Köln");
        eintrag.Email.Should().Be("schaden@huk.de");
    }

    [Fact]
    public async Task MerkeAusAntwort_OhneVersicherername_IstNoOp()
    {
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData
        {
            KeinVersichererErmittelt = true,
            Kennzeichen = "GG-XY 123",
        });

        (await _db.Versicherer.CountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task GetAll_SortiertNachName()
    {
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData { VersichererName = "Zurich" });
        await _wissen.MerkeAusAntwortAsync(new ZentralrufReplyData { VersichererName = "Allianz" });

        var alle = await _wissen.GetAllAsync();
        alle.Select(v => v.Name).Should().ContainInOrder("Allianz", "Zurich");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
