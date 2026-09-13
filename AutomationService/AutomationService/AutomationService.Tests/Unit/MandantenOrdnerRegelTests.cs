using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Ein Ordner gehört höchstens einem Mandanten — auch beim Anlegen und Ändern
/// einzeln, nicht nur beim Import (§5.1, #132). Neben
/// <see cref="MandantenRepositoryTests"/>, weil die Datei sonst über die
/// Grenze von 250 Anweisungszeilen wüchse; geprüft wird dasselbe
/// <see cref="MandantenRepository"/> gegen eine echte In-Memory-SQLite.
/// </summary>
public sealed class MandantenOrdnerRegelTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly MandantenRepository _repository;

    public MandantenOrdnerRegelTests()
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
    public async Task CreateAsync_OrdnerBereitsVergeben_Wirft()
    {
        var inhaber = Neu("Anna", "Klein");
        inhaber.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);
        await _repository.CreateAsync(inhaber);

        var neuer = Neu("Bea", "Groß");
        neuer.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);

        var act = () => _repository.CreateAsync(neuer);

        await act.Should().ThrowAsync<MandantOrdnerConflictException>();
    }

    // Ordnernamen kommen aus dem Windows-Dateisystem und vergleichen sich dort
    // ohne Rücksicht auf Groß-/Kleinschreibung — wie im Import.
    [Fact]
    public async Task UpdateAsync_OrdnerGehoertAnderemMandantenInAndererSchreibweise_Wirft()
    {
        var inhaber = await _repository.CreateAsync(Neu("Anna", "Klein"));
        inhaber.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);
        await _repository.UpdateAsync(inhaber);
        var betroffener = await _repository.CreateAsync(Neu("Bea", "Groß"));

        var aenderung = Neu("Bea", "Groß");
        aenderung.Id = betroffener.Id;
        aenderung.AktenOrdnernamenJson = MandantListen.Schreib(["UNFALL klein"]);

        var act = () => _repository.UpdateAsync(aenderung);

        (await act.Should().ThrowAsync<MandantOrdnerConflictException>())
            .WithMessage("*Anna Klein*");

        // Über eine zweite Verbindung lesen: bei Konflikt darf nichts
        // geschrieben worden sein, auch nicht die übrige Änderung.
        using var zweite = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        var gelesen = await zweite.Mandanten.SingleAsync(m => m.Id == betroffener.Id);
        MandantListen.Lies(gelesen.AktenOrdnernamenJson).Should().BeEmpty();
    }

    // Im Altbestand kann ein Ordner schon zwei Mandanten zugeordnet sein (vor
    // dieser Regel entstanden). Die Regel darf nicht verhindern, dass ein
    // solcher Mandant weiter bearbeitet wird.
    [Fact]
    public async Task UpdateAsync_OrdnerAusAltbestandSchonDoppeltVergeben_Erlaubt()
    {
        var geteilterOrdner = MandantListen.Schreib(["Doppelt Vergeben"]);
        _db.Mandanten.AddRange(
            new MandantEntity
            {
                Id = 1,
                Vorname = "Anna",
                Nachname = "Klein",
                AktenOrdnernamenJson = geteilterOrdner,
                KennzeichenJson = "[]",
            },
            new MandantEntity
            {
                Id = 2,
                Vorname = "Bea",
                Nachname = "Groß",
                AktenOrdnernamenJson = geteilterOrdner,
                KennzeichenJson = "[]",
            });
        await _db.SaveChangesAsync();

        var aenderung = Neu("Bea", "Groß");
        aenderung.Id = 2;
        aenderung.Ort = "Frankfurt";
        aenderung.AktenOrdnernamenJson = geteilterOrdner;

        var aktualisiert = await _repository.UpdateAsync(aenderung);

        aktualisiert.Should().NotBeNull();
        aktualisiert!.Ort.Should().Be("Frankfurt");
    }

    [Fact]
    public async Task UpdateAsync_EigenerOrdnerInAndererSchreibweise_Erlaubt()
    {
        var mandant = await _repository.CreateAsync(Neu("Anna", "Klein"));
        mandant.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);
        await _repository.UpdateAsync(mandant);

        var erneut = Neu("Anna", "Klein");
        erneut.Id = mandant.Id;
        erneut.AktenOrdnernamenJson = MandantListen.Schreib(["UNFALL KLEIN"]);

        var aktualisiert = await _repository.UpdateAsync(erneut);

        aktualisiert.Should().NotBeNull();
        MandantListen.Lies(aktualisiert!.AktenOrdnernamenJson).Should().BeEquivalentTo("UNFALL KLEIN");
    }

    [Fact]
    public async Task UpdateAsync_OrdnerGeloest_ErlaubtUndAndererMandantKannIhnBekommen()
    {
        var erster = await _repository.CreateAsync(Neu("Anna", "Klein"));
        erster.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);
        await _repository.UpdateAsync(erster);

        var geloest = Neu("Anna", "Klein");
        geloest.Id = erster.Id;
        geloest.AktenOrdnernamenJson = "[]";
        await _repository.UpdateAsync(geloest);

        var zweiter = await _repository.CreateAsync(Neu("Bea", "Groß"));
        var uebernimmt = Neu("Bea", "Groß");
        uebernimmt.Id = zweiter.Id;
        uebernimmt.AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]);

        var aktualisiert = await _repository.UpdateAsync(uebernimmt);

        aktualisiert.Should().NotBeNull();
        MandantListen.Lies(aktualisiert!.AktenOrdnernamenJson).Should().BeEquivalentTo("Unfall Klein");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
