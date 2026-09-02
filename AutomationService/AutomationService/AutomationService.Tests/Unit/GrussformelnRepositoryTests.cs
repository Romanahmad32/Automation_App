using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using AutomationService.Features.EmailVersand.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Bestand der persoenlichen Gruesse (§4.7, §7.1) gegen eine echte
/// In-Memory-SQLite: Ausgangsbestand, Reihenfolge, Eindeutigkeit.
/// </summary>
public sealed class GrussformelnRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly GrussformelnRepository _repository;

    public GrussformelnRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        _db.Database.EnsureCreated();
        _repository = new GrussformelnRepository(_db);
    }

    [Fact]
    public async Task Ausgangsbestand_SindDieBeidenAusDerKanzleiMail()
    {
        var alle = await _repository.GetAllAsync();

        alle.Select(g => g.Text).Should()
            .Equal(GrussformelnVorgabe.Ausgangsbestand,
                "der Seed ist beobachtete Praxis, keine zusammengestellte Aufzaehlung");
    }

    [Fact]
    public async Task CreateAsync_HaengtHintenAn_UndVergibtFortlaufendeIds()
    {
        var neu = await _repository.CreateAsync(new GrussformelEntity { Text = "Shalom" });

        neu.Id.Should().Be(3);
        neu.Sortierung.Should().Be(30, "ein neuer Gruss soll die gewohnte Reihenfolge nicht stoeren");
        var alle = await _repository.GetAllAsync();
        alle[^1].Text.Should().Be("Shalom");
    }

    [Fact]
    public async Task CreateAsync_DoppelterGruss_Wirft()
    {
        var act = () => _repository.CreateAsync(new GrussformelEntity { Text = "Salamu aleikum" });

        await act.Should().ThrowAsync<GrussformelTextConflictException>();
    }

    [Fact]
    public async Task UpdateAsync_AendertDenText_UndMeldetUnbekannte()
    {
        var geaendert = await _repository.UpdateAsync(
            new GrussformelEntity { Id = 1, Text = "As-salamu alaykum" });

        geaendert!.Text.Should().Be("As-salamu alaykum");
        geaendert.Sortierung.Should().Be(10, "ohne Angabe bleibt die Reihenfolge stehen");
        (await _repository.UpdateAsync(new GrussformelEntity { Id = 99, Text = "X" }))
            .Should().BeNull();
    }

    [Fact]
    public async Task CreateAsync_LehntLeerenTextAb()
    {
        // <c>IsRequired()</c> verbietet nur NULL: Ueber die API liess sich ein
        // Gruss ohne Wortlaut anlegen — auf dem Schirm ein leerer Chip, und
        // gewaehlt haette er die Grusszeile aus jeder Mail genommen.
        var leer = async () => await _repository.CreateAsync(
            new GrussformelEntity { Text = "   " });

        await leer.Should().ThrowAsync<GrussformelUngueltigException>();
        (await _repository.GetAllAsync()).Should().HaveCount(2,
            "ein abgelehnter Schreibvorgang darf den Bestand nicht anfassen");
    }

    [Fact]
    public async Task CreateAsync_SchneidetLeerraumAb_UndErkenntDenDoppelten()
    {
        var neu = await _repository.CreateAsync(new GrussformelEntity { Text = "  Gruess Gott " });

        neu.Text.Should().Be("Gruess Gott");

        var nochmal = async () => await _repository.CreateAsync(
            new GrussformelEntity { Text = " Gruess Gott" });

        await nochmal.Should().ThrowAsync<GrussformelTextConflictException>(
            "getrimmt ist es derselbe Gruss — zwei gleiche Chips waeren nicht "
            + "auseinanderzuhalten");
    }

    [Fact]
    public async Task UpdateAsync_LehntLeerenTextAb()
    {
        var leer = async () => await _repository.UpdateAsync(
            new GrussformelEntity { Id = 1, Text = string.Empty });

        await leer.Should().ThrowAsync<GrussformelUngueltigException>();
        (await _repository.GetAllAsync()).Should().NotContain(g => g.Text.Length == 0);
    }

    [Fact]
    public async Task DeleteAsync_EntferntUndMeldetUnbekannte()
    {
        (await _repository.DeleteAsync(1)).Should().BeTrue();
        (await _repository.DeleteAsync(99)).Should().BeFalse();
        (await _repository.GetAllAsync()).Should().ContainSingle();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
