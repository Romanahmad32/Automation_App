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

    // Die Mandantenliste zeigt in der Kanzlei tausende Eintraege. Sie holt
    // deshalb Ausschnitte — und die Suche muss trotzdem den ganzen Bestand
    // sehen, sonst haenge es am Scrollstand, ob ein Mandant gefunden wird.
    [Fact]
    public async Task GetSeiteAsync_LiefertNurDenAusschnittUndBeideZahlen()
    {
        for (var i = 0; i < 5; i++) await _repository.CreateAsync(Neu(nachname: $"Nr{i}"));

        var seite = await _repository.GetSeiteAsync(suche: null, ueberspringen: 2, anzahl: 2);

        seite.Mandanten.Should().HaveCount(2);
        seite.Gesamt.Should().Be(5);
        seite.Gefiltert.Should().Be(5);
    }

    // Ein Import legt tausende Mandanten in derselben Sekunde an: ohne zweite
    // Sortierstufe teilten zwei Abrufe den Bestand verschieden auf.
    [Fact]
    public async Task GetSeiteAsync_TeiltDenBestandUeberlappungsfreiAuf()
    {
        for (var i = 0; i < 6; i++) await _repository.CreateAsync(Neu(nachname: $"Nr{i}"));

        var erste = await _repository.GetSeiteAsync(null, ueberspringen: 0, anzahl: 3);
        var zweite = await _repository.GetSeiteAsync(null, ueberspringen: 3, anzahl: 3);

        var ids = erste.Mandanten.Concat(zweite.Mandanten).Select(m => m.Id).ToList();
        ids.Should().OnlyHaveUniqueItems().And.HaveCount(6);
    }

    [Fact]
    public async Task GetSeiteAsync_SuchtUeberNameOrtUndOrdner()
    {
        var mitOrdner = Neu("Mark", "Schmidt");
        mitOrdner.AktenOrdnernamenJson = MandantListen.Schreib(["VUnfallursache Mark"]);
        await _repository.CreateAsync(mitOrdner);

        var ausFrankfurt = Neu("Saeed", "Bein");
        ausFrankfurt.Ort = "Frankfurt";
        await _repository.CreateAsync(ausFrankfurt);

        (await _repository.GetSeiteAsync("mark schmidt", 0, 50)).Gefiltert.Should().Be(1);
        (await _repository.GetSeiteAsync("frankfurt", 0, 50)).Gefiltert.Should().Be(1);
        (await _repository.GetSeiteAsync("VUnfallursache", 0, 50)).Gefiltert.Should().Be(1);
        (await _repository.GetSeiteAsync("nichts davon", 0, 50)).Gefiltert.Should().Be(0);
    }

    // Ein Prozentzeichen im Suchbegriff ist ein Zeichen, kein Platzhalter.
    [Fact]
    public async Task GetSeiteAsync_NimmtLikePlatzhalterWoertlich()
    {
        await _repository.CreateAsync(Neu("Max", "Müller"));

        var seite = await _repository.GetSeiteAsync("%", 0, 50);

        seite.Gefiltert.Should().Be(0);
        seite.Gesamt.Should().Be(1);
    }

    [Fact]
    public async Task GetAktenOrdnernamenAsync_LiefertAlleZugeordnetenOrdner()
    {
        var a = Neu(nachname: "Schmidt");
        a.AktenOrdnernamenJson = MandantListen.Schreib(["VUnfallursache Mark", "Strafsache Mark"]);
        await _repository.CreateAsync(a);
        var b = Neu(nachname: "Bein");
        b.AktenOrdnernamenJson = MandantListen.Schreib(["OWi Bein"]);
        await _repository.CreateAsync(b);

        var namen = await _repository.GetAktenOrdnernamenAsync();

        namen.Should().BeEquivalentTo("VUnfallursache Mark", "Strafsache Mark", "OWi Bein");
    }

    [Fact]
    public async Task UpdateAsync_UebernimmtDiePersoenlicheGrussformel()
    {
        var angelegt = await _repository.CreateAsync(Neu(nachname: "Bein"));
        angelegt.PersoenlicheGrussformel.Should()
            .BeEmpty("ohne Angabe gibt es keinen Zusatzgruss");

        var geaendert = Neu(nachname: "Bein");
        geaendert.Id = angelegt.Id;
        geaendert.PersoenlicheGrussformel = "Salamu aleikum";
        await _repository.UpdateAsync(geaendert);

        // Über eine zweite Verbindung zur selben Datei lesen: Der Änderungs-
        // verfolger des ersten Kontexts würde die Eigenschaft auch dann
        // zurückgeben, wenn sie nie in eine Spalte geschrieben worden wäre.
        using var zweiter = new AutomationDbContext(
            new DbContextOptionsBuilder<AutomationDbContext>()
                .UseSqlite(_connection)
                .Options);
        var gelesen = await zweiter.Mandanten.SingleAsync(m => m.Id == angelegt.Id);
        gelesen.PersoenlicheGrussformel.Should().Be("Salamu aleikum");
    }

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
