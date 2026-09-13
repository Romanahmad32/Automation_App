using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Einen einzelnen Ordner geben und nehmen (#132) — der Weg für Karte, Stapel
/// und Ablage. Neben <see cref="MandantenOrdnerRegelTests"/>, weil jene Datei
/// die Regel beim Anlegen und Ändern im Ganzen prüft und sonst über die Grenze
/// von 250 Anweisungszeilen wüchse.
/// </summary>
public sealed class MandantenOrdnerZuordnungTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly OrdnerStatusRegister _vermerke;
    private readonly MandantenRepository _repository;

    public MandantenOrdnerZuordnungTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        _db.Database.EnsureCreated();
        _vermerke = new OrdnerStatusRegister(_db);
        _repository = new MandantenRepository(_db, _vermerke);
    }

    /// <summary>Legt Mandanten an der Regel vorbei an — so, wie der Altbestand aussehen kann.</summary>
    private async Task Bestand(params (int Id, string Nachname, string[] Ordner)[] mandanten)
    {
        foreach (var (id, nachname, ordner) in mandanten)
        {
            _db.Mandanten.Add(new MandantEntity
            {
                Id = id,
                Nachname = nachname,
                AktenOrdnernamenJson = MandantListen.Schreib(ordner),
                KennzeichenJson = "[]",
            });
        }
        await _db.SaveChangesAsync();
    }

    /// <summary>Die Ordner eines Mandanten, über eine zweite Verbindung frisch gelesen.</summary>
    private List<string> OrdnerVon(int id)
    {
        using var zweite = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>().UseSqlite(_connection).Options);
        return MandantListen.Lies(zweite.Mandanten.Single(m => m.Id == id).AktenOrdnernamenJson);
    }

    [Fact]
    public async Task OrdnerZuordnen_HaengtDenOrdnerAn_UndLaesstDieUebrigenStehen()
    {
        await Bestand((1, "Klein", ["Unfall Klein"]));

        var mandant = await _repository.OrdnerZuordnenAsync(1, "  Bußgeld Klein ", nurPruefen: false);

        mandant.Should().NotBeNull();
        OrdnerVon(1).Should().Equal("Unfall Klein", "Bußgeld Klein");
    }

    [Fact]
    public async Task OrdnerZuordnen_FremderOrdner_WirftUndSchreibtNichts()
    {
        await Bestand((1, "Klein", ["Unfall Klein"]), (2, "Groß", []));

        var act = () => _repository.OrdnerZuordnenAsync(2, "UNFALL klein", nurPruefen: false);

        (await act.Should().ThrowAsync<MandantOrdnerConflictException>()).WithMessage("*Klein*");
        OrdnerVon(2).Should().BeEmpty();
    }

    // Im Altbestand gehört ein Ordner zwei Mandanten. Die Ablage in die eigene
    // Akte prüft vor dem Kopieren und ordnet danach zu — beides muss gehen,
    // sonst ist ein solcher Mandant für die Ablage verloren.
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task OrdnerZuordnen_EigenerOrdnerAusAltbestandDoppelt_Erlaubt(bool nurPruefen)
    {
        await Bestand((1, "Klein", ["Doppelt"]), (2, "Groß", ["Doppelt"]));

        var mandant = await _repository.OrdnerZuordnenAsync(1, "doppelt", nurPruefen);

        mandant.Should().NotBeNull();
        OrdnerVon(1).Should().Equal("Doppelt");
    }

    [Fact]
    public async Task OrdnerZuordnen_NurPruefen_SchreibtNichts()
    {
        await Bestand((1, "Klein", []));
        await _vermerke.SetzeAsync(["Unfall Klein"], OrdnerStatusArten.OhneMandantenbezug);

        var mandant = await _repository.OrdnerZuordnenAsync(1, "Unfall Klein", nurPruefen: true);

        mandant.Should().NotBeNull();
        OrdnerVon(1).Should().BeEmpty();
        (await _vermerke.GetAllAsync()).Should().ContainSingle();
    }

    [Fact]
    public async Task OrdnerZuordnen_NimmtDenVermerkZurueck()
    {
        await Bestand((1, "Klein", []));
        await _vermerke.SetzeAsync(["Unfall Klein"], OrdnerStatusArten.OhneMandantenbezug);

        await _repository.OrdnerZuordnenAsync(1, "UNFALL KLEIN", nurPruefen: false);

        (await _vermerke.GetAllAsync()).Should().BeEmpty();
    }

    // Der neue Mandant aus dem Zuordnungsstapel kommt mit vorbelegtem Ordner
    // über CreateAsync — auch dort sticht die Zuordnung den Vermerk.
    [Fact]
    public async Task CreateAsync_NimmtDenVermerkAufSeinenOrdnernZurueck()
    {
        await _vermerke.SetzeAsync(["Unfall Klein", "Anderes"], OrdnerStatusArten.OhneMandantenbezug);

        await _repository.CreateAsync(new MandantEntity
        {
            Nachname = "Klein",
            AktenOrdnernamenJson = MandantListen.Schreib(["unfall klein"]),
            KennzeichenJson = "[]",
        });

        (await _vermerke.GetAllAsync()).Select(v => v.Ordnername).Should().Equal("Anderes");
    }

    [Fact]
    public async Task UpdateAsync_NimmtDenVermerkAufNeuenOrdnernZurueck()
    {
        await Bestand((1, "Klein", []));
        await _vermerke.SetzeAsync(["Unfall Klein"], OrdnerStatusArten.OhneMandantenbezug);

        await _repository.UpdateAsync(new MandantEntity
        {
            Id = 1,
            Nachname = "Klein",
            AktenOrdnernamenJson = MandantListen.Schreib(["Unfall Klein"]),
            KennzeichenJson = "[]",
        });

        (await _vermerke.GetAllAsync()).Should().BeEmpty();
    }

    // Gespeichert mit Leerzeichen am Rand (Altbestand, von Hand eingetragen):
    // Das Frontend hält den Ordner für vergeben — das Backend muss es auch.
    [Fact]
    public async Task OrdnerZuordnen_GespeicherterNameMitLeerzeichen_GiltAlsVergeben()
    {
        await Bestand((1, "Klein", [" Unfall Klein "]), (2, "Groß", []));

        var act = () => _repository.OrdnerZuordnenAsync(2, "Unfall Klein", nurPruefen: false);

        await act.Should().ThrowAsync<MandantOrdnerConflictException>();
    }

    [Fact]
    public async Task UpdateAsync_EigenerOrdnerMitLeerzeichen_GiltNichtAlsNeu()
    {
        await Bestand((1, "Klein", ["Doppelt"]), (2, "Groß", ["Doppelt"]));

        var aktualisiert = await _repository.UpdateAsync(new MandantEntity
        {
            Id = 1,
            Nachname = "Klein",
            AktenOrdnernamenJson = MandantListen.Schreib(["Doppelt "]),
            KennzeichenJson = "[]",
        });

        aktualisiert.Should().NotBeNull();
    }

    [Fact]
    public async Task OrdnerLoesen_NimmtDenOrdnerInJederSchreibweise_UndLaesstDieUebrigenStehen()
    {
        await Bestand((1, "Klein", ["Unfall Klein", "Bußgeld Klein"]));

        var mandant = await _repository.OrdnerLoesenAsync(1, "UNFALL klein ");

        mandant.Should().NotBeNull();
        OrdnerVon(1).Should().Equal("Bußgeld Klein");
    }

    [Fact]
    public async Task UnbekannteId_LiefertNull()
    {
        (await _repository.OrdnerZuordnenAsync(99, "Unfall", nurPruefen: false)).Should().BeNull();
        (await _repository.OrdnerLoesenAsync(99, "Unfall")).Should().BeNull();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
