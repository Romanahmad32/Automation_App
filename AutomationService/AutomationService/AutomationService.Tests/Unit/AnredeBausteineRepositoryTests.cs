using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using AutomationService.Features.EmailVersand.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Bestand der Anredeanfaenge (§4.7, §7.1) gegen eine echte
/// In-Memory-SQLite: Ausgangsbestand, Reihenfolge, Eindeutigkeit.
/// </summary>
public sealed class AnredeBausteineRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly AnredeBausteineRepository _repository;

    public AnredeBausteineRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        _db.Database.EnsureCreated();
        _repository = new AnredeBausteineRepository(_db);
    }

    [Fact]
    public async Task Ausgangsbestand_BeginntMitSehrGeehrt()
    {
        var alle = await _repository.GetAllAsync();

        alle[0].Maennlich.Should().Be("Sehr geehrter");
        alle[0].Weiblich.Should().Be("Sehr geehrte");
        alle[0].Id.Should().Be(AnredeBausteineVorgabe.SehrGeehrtId,
            "der erste gilt beim Verfassen ohne Klick und muss die Anrede "
            + "reproduzieren, die die App vorher fest erzeugt hat");
    }

    [Fact]
    public async Task Ausgangsbestand_EnthaeltEinenAnfangOhneBeugung()
    {
        var alle = await _repository.GetAllAsync();

        var gutenTag = alle.Should().ContainSingle(a => a.Maennlich == "Guten Tag").Subject;
        gutenTag.Weiblich.Should().Be("Guten Tag");
        gutenTag.Neutral.Should().Be("Guten Tag",
            "dass alle drei Formen gleich lauten duerfen, ist kein Sonderfall");
    }

    [Fact]
    public async Task CreateAsync_HaengtHintenAn_UndVergibtFortlaufendeIds()
    {
        var neu = await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "Lieber",
            Weiblich = "Liebe",
            Neutral = "Liebe",
        });

        neu.Id.Should().Be(3);
        neu.Sortierung.Should().Be(30,
            "ein neuer Anfang soll die gewohnte Reihenfolge nicht stoeren");
        var alle = await _repository.GetAllAsync();
        alle[^1].Maennlich.Should().Be("Lieber");
    }

    [Fact]
    public async Task CreateAsync_AlleDreiFormenGleich_Wirft()
    {
        var act = () => _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "Guten Tag",
            Weiblich = "Guten Tag",
            Neutral = "Guten Tag",
        });

        await act.Should().ThrowAsync<AnredeBausteinConflictException>();
    }

    [Fact]
    public async Task CreateAsync_GleicheMaennlicheFormAberAndereWeibliche_IstEinAndererBaustein()
    {
        // Der fachliche Schluessel sind alle drei Formen: „Guten Tag" mit einer
        // anderen weiblichen Form ist ein anderer Baustein.
        var neu = await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "Guten Tag",
            Weiblich = "Guten Tag, Frau",
            Neutral = "Guten Tag",
        });

        neu.Id.Should().Be(3);
    }

    [Fact]
    public async Task UpdateAsync_UnbekannteId_LiefertNull()
    {
        var geaendert = await _repository.UpdateAsync(new AnredeBausteinEntity
        {
            Id = 99,
            Maennlich = "Hallo",
            Weiblich = "Hallo",
            Neutral = "Hallo",
        });

        geaendert.Should().BeNull();
    }

    [Fact]
    public async Task UpdateAsync_SchreibtAlleDreiFormen()
    {
        var geaendert = await _repository.UpdateAsync(new AnredeBausteinEntity
        {
            Id = AnredeBausteineVorgabe.SehrGeehrtId,
            Maennlich = "Sehr verehrter",
            Weiblich = "Sehr verehrte",
            Neutral = "Sehr verehrte",
        });

        geaendert!.Maennlich.Should().Be("Sehr verehrter");
        geaendert.Weiblich.Should().Be("Sehr verehrte");
        geaendert.Neutral.Should().Be("Sehr verehrte");
    }

    [Fact]
    public async Task CreateAsync_LehntLeereFormenAb()
    {
        // <c>IsRequired()</c> verbietet nur NULL: Ueber die API liess sich ein
        // namenloser Anredeanfang anlegen. Auf dem Schirm war das ein leerer
        // Chip, und stand er vorn, begann jede Mail ohne Anredebeginn.
        var leer = async () => await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "  ",
            Weiblich = string.Empty,
            Neutral = "Sehr geehrte",
        });

        await leer.Should().ThrowAsync<AnredeBausteinUngueltigException>()
            .Where(a => a.Message.Contains("maennlich") && a.Message.Contains("weiblich"));
    }

    [Fact]
    public async Task CreateAsync_SchneidetLeerraumAb()
    {
        var neu = await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "  Lieber ",
            Weiblich = " Liebe",
            Neutral = "Liebe ",
        });

        neu.Maennlich.Should().Be("Lieber");
        neu.Weiblich.Should().Be("Liebe");
        neu.Neutral.Should().Be("Liebe");
    }

    [Fact]
    public async Task UpdateAsync_LehntLeereFormenAb()
    {
        var leer = async () => await _repository.UpdateAsync(new AnredeBausteinEntity
        {
            Id = AnredeBausteineVorgabe.SehrGeehrtId,
            Maennlich = "Sehr geehrter",
            Weiblich = "Sehr geehrte",
            Neutral = string.Empty,
        });

        await leer.Should().ThrowAsync<AnredeBausteinUngueltigException>();

        var alle = await _repository.GetAllAsync();
        alle.Should().Contain(a => a.Neutral == "Sehr geehrte",
            "ein abgelehnter Schreibvorgang darf den Bestand nicht anfassen");
    }

    [Fact]
    public async Task DeleteAsync_EntferntUndMeldetUnbekannteId()
    {
        (await _repository.DeleteAsync(AnredeBausteineVorgabe.SehrGeehrtId)).Should().BeTrue();
        (await _repository.DeleteAsync(AnredeBausteineVorgabe.SehrGeehrtId)).Should().BeFalse();

        var alle = await _repository.GetAllAsync();
        alle.Should().NotContain(a => a.Id == AnredeBausteineVorgabe.SehrGeehrtId);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
    [Fact]
    public async Task Anlegen_ErkenntDenAnfangOhneRuecksichtAufGrossschreibung()
    {
        // "Moin" und "MOIN" sind auf dem Schirm derselbe Chip
        // (behoben am 03.09.2026).
        await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "Moin",
            Weiblich = "Moin",
            Neutral = "Moin",
        });

        var tat = async () => await _repository.CreateAsync(new AnredeBausteinEntity
        {
            Maennlich = "MOIN",
            Weiblich = "moin",
            Neutral = "Moin",
        });

        await tat.Should().ThrowAsync<AnredeBausteinConflictException>();
    }

}
