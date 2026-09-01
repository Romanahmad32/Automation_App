using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using AutomationService.Features.EmailVersand.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Bestand der Mail-Textvorlagen (§4.7) gegen eine echte In-Memory-SQLite:
/// Ausgangsbestand, Id-Vergabe, eindeutige Namen.
/// </summary>
public sealed class MailVorlagenRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly MailVorlagenRepository _repository;

    public MailVorlagenRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        _db.Database.EnsureCreated();
        _repository = new MailVorlagenRepository(_db);
    }

    private static MailVorlageEntity Neu(string name, string betreff = "", string text = "")
        => new() { Name = name, Betreff = betreff, Text = text };

    [Fact]
    public async Task Ausgangsbestand_IstDasKanzleiAnschreiben()
    {
        var alle = await _repository.GetAllAsync();

        var vorlage = alle.Should().ContainSingle().Subject;
        vorlage.Id.Should().Be(MailVorlagenVorgabe.MandantenanschreibenId);
        vorlage.Name.Should().Be(MailVorlagenVorgabe.MandantenanschreibenName);
    }

    [Fact]
    public void Ausgangsbestand_TraegtDiePlatzhalterUndKeineSignatur()
    {
        var text = MailVorlagenVorgabe.Mandantenanschreiben;

        text.Should().Contain("{{Anrede}}").And.Contain("{{Grussformel}}");
        text.Should().EndWith("Mit freundlichen Grüßen",
            "die Signatur haengt der Versand an — im Vorlagentext stuende sie doppelt");
        text.Should().NotContain("Sehr geehrter Herr/Frau",
            "die Anrede bildet die App, sie steht nicht als Handplatzhalter im Text");
    }

    [Fact]
    public async Task CreateAsync_VergibtFortlaufendeIds()
    {
        var a = await _repository.CreateAsync(Neu("Nachfrage an die Versicherung"));
        var b = await _repository.CreateAsync(Neu("Sachstand an den Mandanten"));

        // Die 1 ist an den Ausgangsbestand vergeben.
        a.Id.Should().Be(2);
        b.Id.Should().Be(3);
    }

    [Fact]
    public async Task CreateAsync_DoppelterName_Wirft()
    {
        var act = () => _repository.CreateAsync(Neu(MailVorlagenVorgabe.MandantenanschreibenName));

        await act.Should().ThrowAsync<MailVorlageNameConflictException>();
    }

    [Fact]
    public async Task UpdateAsync_AendertBetreffUndText_UndMeldetUnbekannte()
    {
        var geaendert = Neu("Anschreiben an den Mandanten", "Neuer Betreff", "Neuer Text");
        geaendert.Id = MailVorlagenVorgabe.MandantenanschreibenId;

        var ergebnis = await _repository.UpdateAsync(geaendert);

        ergebnis!.Betreff.Should().Be("Neuer Betreff");
        ergebnis.Text.Should().Be("Neuer Text");
        (await _repository.UpdateAsync(Neu("Unbekannt"))).Should().BeNull();
    }

    [Fact]
    public async Task DeleteAsync_EntferntUndMeldetUnbekannte()
    {
        (await _repository.DeleteAsync(MailVorlagenVorgabe.MandantenanschreibenId))
            .Should().BeTrue();
        (await _repository.DeleteAsync(999)).Should().BeFalse();
        (await _repository.GetAllAsync()).Should().BeEmpty();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
