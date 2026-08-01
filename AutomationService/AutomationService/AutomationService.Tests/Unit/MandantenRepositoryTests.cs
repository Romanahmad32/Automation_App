using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die ins Backend gewanderten Mandanten-Fachregeln (fortlaufende IDs,
/// Namens-Dublettenprüfung) gegen eine echte In-Memory-SQLite. Diese Regeln
/// lagen früher im lokalen Flutter-Datasource und werden hier weiter abgedeckt.
/// </summary>
public sealed class MandantenRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly MandantenRepository _repository;

    public MandantenRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _repository = new MandantenRepository(_db);
    }

    private static MandantEntity Neu(string vorname = "", string nachname = "") => new()
    {
        Vorname = vorname,
        Nachname = nachname,
        AktenOrdnernamenJson = "[]",
        KennzeichenJson = "[]",
    };

    [Fact]
    public async Task CreateAsync_VergibtFortlaufendeIds()
    {
        var a = await _repository.CreateAsync(Neu(nachname: "Bein"));
        var b = await _repository.CreateAsync(Neu(nachname: "Müller"));

        a.Id.Should().Be(1);
        b.Id.Should().Be(2);
    }

    [Fact]
    public async Task CreateAsync_DoppelterNormalisierterName_Wirft()
    {
        await _repository.CreateAsync(Neu("Max", "Müller"));

        var act = () => _repository.CreateAsync(Neu("  MAX ", "müller"));

        await act.Should().ThrowAsync<MandantNameConflictException>();
    }

    [Fact]
    public async Task CreateAsync_AndererName_Erlaubt()
    {
        await _repository.CreateAsync(Neu("Max", "Müller"));

        var anderer = await _repository.CreateAsync(Neu("Max", "Meier"));

        anderer.Id.Should().Be(2);
    }

    [Fact]
    public async Task UpdateAsync_Namenskollision_Wirft()
    {
        var a = await _repository.CreateAsync(Neu("Anna", "Klein"));
        await _repository.CreateAsync(Neu("Bea", "Groß"));

        var kollision = Neu("Bea", "Groß");
        kollision.Id = a.Id;

        var act = () => _repository.UpdateAsync(kollision);

        await act.Should().ThrowAsync<MandantNameConflictException>();
    }

    [Fact]
    public async Task UpdateAsync_EigenerNameUnveraendert_IstErlaubt()
    {
        var a = await _repository.CreateAsync(Neu("Anna", "Klein"));

        var aenderung = Neu("Anna", "Klein");
        aenderung.Id = a.Id;
        aenderung.Ort = "Frankfurt";

        var aktualisiert = await _repository.UpdateAsync(aenderung);

        aktualisiert.Should().NotBeNull();
        aktualisiert!.Ort.Should().Be("Frankfurt");
    }

    [Fact]
    public async Task UpdateAsync_UnbekannteId_LiefertNull()
    {
        var unbekannt = Neu(nachname: "Geist");
        unbekannt.Id = 999;

        var result = await _repository.UpdateAsync(unbekannt);

        result.Should().BeNull();
    }

    [Fact]
    public async Task DeleteAsync_EntferntUndMeldetUnbekannte()
    {
        var m = await _repository.CreateAsync(Neu(nachname: "Bein"));

        (await _repository.DeleteAsync(m.Id)).Should().BeTrue();
        (await _repository.DeleteAsync(999)).Should().BeFalse();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
