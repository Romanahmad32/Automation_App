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

        text.Should().Contain("{{Anrede}}").And.Contain("{{Zusatzgruß}}");
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
    public async Task CreateAsync_LehntEineVorlageOhneNamenAb()
    {
        // <c>IsRequired()</c> verbietet nur NULL: Ueber die API liess sich ein
        // namenloser Eintrag anlegen. Der Name ist der fachliche Schluessel —
        // danach waehlt der Anwalt beim Verfassen.
        var ohneNamen = async () => await _repository.CreateAsync(Neu("   "));

        await ohneNamen.Should().ThrowAsync<MailVorlageUngueltigException>();
        (await _repository.GetAllAsync()).Should().ContainSingle(
            "ein abgelehnter Schreibvorgang darf den Bestand nicht anfassen");
    }

    [Fact]
    public async Task CreateAsync_NimmtEineHalbGeschriebeneVorlageAn()
    {
        // Die Gegenprobe, und die wichtigere Zusage (§1.3, §4.7): Betreff und
        // Text duerfen leer bleiben. Der Vorlageneditor ist ein Hinweisgeber,
        // kein Riegel — wer beim Schreiben unterbrochen wird, muss speichern
        // koennen.
        var angelegt = await _repository.CreateAsync(Neu("Noch im Bau"));

        angelegt.Name.Should().Be("Noch im Bau");
        angelegt.Betreff.Should().BeEmpty();
        angelegt.Text.Should().BeEmpty();
    }

    [Fact]
    public async Task CreateAsync_SchneidetNamenUndBetreffAb_UndLaesstDenTextInRuhe()
    {
        var angelegt = await _repository.CreateAsync(
            Neu("  Nachfrage ", "  Zu Ihrem Schreiben  ", "\nMit Leerzeile davor"));

        angelegt.Name.Should().Be("Nachfrage");
        angelegt.Betreff.Should().Be("Zu Ihrem Schreiben");
        angelegt.Text.Should().Be("\nMit Leerzeile davor",
            "im Text ist Leerraum Aufbau, keine Unachtsamkeit");
    }

    [Fact]
    public async Task CreateAsync_ErkenntDenDoppeltenNamenAuchMitLeerraum()
    {
        var doppelt = async () => await _repository.CreateAsync(
            Neu($" {MailVorlagenVorgabe.MandantenanschreibenName} "));

        await doppelt.Should().ThrowAsync<MailVorlageNameConflictException>(
            "getrimmt ist es derselbe Name — zwei gleiche Zeilen waeren in der "
            + "Auswahl nicht auseinanderzuhalten");
    }

    [Fact]
    public async Task UpdateAsync_LehntEineVorlageOhneNamenAb()
    {
        var ohneNamen = async () => await _repository.UpdateAsync(new MailVorlageEntity
        {
            Id = MailVorlagenVorgabe.MandantenanschreibenId,
            Name = string.Empty,
            Text = "Bleibt so",
        });

        await ohneNamen.Should().ThrowAsync<MailVorlageUngueltigException>();
        (await _repository.GetAllAsync()).Should().NotContain(v => v.Name.Length == 0);
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
    [Fact]
    public async Task Anlegen_ErkenntDenNamenOhneRuecksichtAufGrossschreibung()
    {
        // Der Klassenkommentar der Entitaet versprach das von Anfang an, die
        // Spalte trug aber BINARY: "anschreiben" ging neben "Anschreiben"
        // durch, und in der Auswahl beim Verfassen standen zwei Eintraege, die
        // der Anwalt nicht auseinanderhalten kann (behoben am 03.09.2026).
        await _repository.CreateAsync(Neu("Kurzmitteilung"));

        var tat = async () => await _repository.CreateAsync(Neu("kurzMITTEILUNG"));

        await tat.Should().ThrowAsync<MailVorlageNameConflictException>();
    }

    [Fact]
    public async Task Umbenennen_ErkenntDenNamenOhneRuecksichtAufGrossschreibung()
    {
        var erste = await _repository.CreateAsync(Neu("Kurzmitteilung"));
        var zweite = await _repository.CreateAsync(Neu("Sachstand"));

        zweite.Name = "KURZMITTEILUNG";
        var tat = async () => await _repository.UpdateAsync(zweite);

        await tat.Should().ThrowAsync<MailVorlageNameConflictException>();
        erste.Name.Should().Be("Kurzmitteilung");
    }

    [Fact]
    public async Task Umbenennen_DerEigenenZeileBleibtErlaubt()
    {
        // Die Gegenprobe: `eigeneId` haelt den Eintrag von sich selbst frei —
        // sonst waere jede Aenderung an einer Vorlage ein Konflikt mit ihr.
        var vorlage = await _repository.CreateAsync(Neu("Kurzmitteilung"));

        vorlage.Betreff = "Neuer Betreff";
        var geschrieben = await _repository.UpdateAsync(vorlage);

        geschrieben!.Betreff.Should().Be("Neuer Betreff");
    }

}
