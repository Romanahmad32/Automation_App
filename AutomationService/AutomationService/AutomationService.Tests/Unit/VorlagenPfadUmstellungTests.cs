using AutomationService.Core.Persistence;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.FormTemplates.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die einmalige Umstellung des Bestands (#33): Wer den Vorlagenordner waehlt,
/// dessen absolute Bestandspfade darin werden relativiert — aussenliegende
/// bleiben stehen. Ohne das hilft der einstellbare Ordner niemandem, dessen
/// Datenbank weiter auf C:\Users\&lt;Name&gt;\... zeigt.
///
/// Der zweite Fall ist der teurere und stand lange nicht hier: ein Bestand, der
/// schon relativ ist (#130). Er ist zweideutig — derselbe Pfad meint die Datei
/// in A oder die in B —, und die Datenbank sagt nicht, welche. Deshalb drei
/// Faelle statt einem: Datei liegt noch im alten Ordner (absolut werden), Datei
/// ist mitgewandert (relativ bleiben), Datei nirgends (nichts anfassen).
/// </summary>
public sealed class VorlagenPfadUmstellungTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;

    public VorlagenPfadUmstellungTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
    }

    /// <summary>
    /// Die Platte als Nachschlagewerk: Nur was hier steht, gibt es. So kommt
    /// die Fallunterscheidung ohne echte Dateien aus — und ohne den Zufall,
    /// dass auf dem Rechner des Bauplans zufaellig ein <c>C:\A</c> liegt.
    /// </summary>
    private static Func<string, bool> NurDiese(params string[] pfade) =>
        pfad => pfade.Contains(pfad, StringComparer.OrdinalIgnoreCase);

    [Fact]
    public async Task StelleUm_RelativiertPfadeImOrdnerUndLaesstDenRestStehen()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Im Ordner",
            WordFilePathOhneAuflistung = @"C:\Kanzlei\Vorlagen\Anspruch.docx",
            WordFilePathMitAuflistung = @"C:\Woanders\Auflistung.docx",
        });
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 2,
            TemplateName = "Ohne Pfade",
            WordFilePathOhneAuflistung = null,
            WordFilePathMitAuflistung = null,
        });
        await _db.SaveChangesAsync();

        var geaendert = await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\Alt\Vorlagen", @"C:\Kanzlei\Vorlagen", CancellationToken.None);
        _db.ChangeTracker.Clear();

        geaendert.Should().Be(1);
        var imOrdner = await _db.FormTemplates.SingleAsync(t => t.Id == 1);
        imOrdner.WordFilePathOhneAuflistung.Should().Be("Anspruch.docx");
        imOrdner.WordFilePathMitAuflistung.Should().Be(@"C:\Woanders\Auflistung.docx");
        var ohnePfade = await _db.FormTemplates.SingleAsync(t => t.Id == 2);
        ohnePfade.WordFilePathOhneAuflistung.Should().BeNull();
        ohnePfade.WordFilePathMitAuflistung.Should().BeNull();
    }

    [Fact]
    public async Task StelleUm_OhneTrefferSchreibtNichtsUndMeldetNull()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Schon relativ",
            WordFilePathOhneAuflistung = "Anspruch.docx",
            WordFilePathMitAuflistung = null,
        });
        await _db.SaveChangesAsync();

        var geaendert = await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\Kanzlei\Vorlagen", @"C:\Kanzlei\Vorlagen", CancellationToken.None);

        geaendert.Should().Be(0);
    }

    /// <summary>
    /// Der Fall aus der Kanzlei (#130): Der Bestand steht relativ zu Ordner A,
    /// dann setzt der Anwalt den App-Daten-Ordner und der wirksame Vorlagen-
    /// ordner wird B. Frueher blieb "Anspruch.docx" stehen und wurde ab da
    /// gegen B gelesen — dort lag die Datei nie, und alle vier Vorlagen
    /// meldeten "Die verknuepfte Word-Datei wurde nicht gefunden". Jetzt zeigt
    /// der Pfad weiter auf die Datei, auch wenn er dafuer absolut werden muss.
    ///
    /// Die Dateien sind <em>nicht</em> mitgewandert: Sie liegen weiter in A.
    /// Genau das unterscheidet diesen Fall vom naechsten.
    /// </summary>
    [Fact]
    public async Task StelleUm_HaeltEinenRelativenBestandAuffindbar()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Relativ zu A",
            WordFilePathOhneAuflistung = "Anspruch.docx",
            WordFilePathMitAuflistung = @"Unterordner\Auflistung.docx",
        });
        await _db.SaveChangesAsync();

        var geaendert = await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\A\Vorlagen", @"C:\B\Vorlagen",
            NurDiese(
                @"C:\A\Vorlagen\Anspruch.docx",
                @"C:\A\Vorlagen\Unterordner\Auflistung.docx"),
            CancellationToken.None);
        _db.ChangeTracker.Clear();

        geaendert.Should().Be(1);
        var vorlage = await _db.FormTemplates.SingleAsync(t => t.Id == 1);
        VorlagenPfad.LoeseAuf(@"C:\B\Vorlagen", vorlage.WordFilePathOhneAuflistung)
            .Should().Be(@"C:\A\Vorlagen\Anspruch.docx");
        VorlagenPfad.LoeseAuf(@"C:\B\Vorlagen", vorlage.WordFilePathMitAuflistung)
            .Should().Be(@"C:\A\Vorlagen\Unterordner\Auflistung.docx");
    }

    /// <summary>
    /// Die Gegenrichtung — und der Grund, warum ueberhaupt nachgesehen wird
    /// (#130): Der Anwalt nimmt seine Vorlagen in den neuen Ordner mit und
    /// stellt die Einstellung erst danach um. Der Bestand ist derselbe relative
    /// Pfad wie oben, gemeint ist aber die Datei in B. Wer ihn hier gegen A
    /// aufloeste, machte aus einer mitnehmbaren Verknuepfung wieder ein
    /// <c>C:\Users\&lt;Name&gt;\…</c> auf einen Ordner, den der Anwalt gerade
    /// verlassen hat — #33 rueckwaerts.
    /// </summary>
    [Fact]
    public async Task StelleUm_BleibtRelativWennDieDateiImNeuenOrdnerLiegt()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Mitgenommen",
            WordFilePathOhneAuflistung = "Anspruch.docx",
            WordFilePathMitAuflistung = null,
        });
        await _db.SaveChangesAsync();

        var geaendert = await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\A\Vorlagen", @"C:\B\Vorlagen",
            NurDiese(@"C:\B\Vorlagen\Anspruch.docx"),
            CancellationToken.None);
        _db.ChangeTracker.Clear();

        geaendert.Should().Be(0);
        var vorlage = await _db.FormTemplates.SingleAsync(t => t.Id == 1);
        vorlage.WordFilePathOhneAuflistung.Should().Be("Anspruch.docx");
    }

    /// <summary>
    /// Ist die Datei in beiden Ordnern nicht zu finden, gibt es nichts zu
    /// entscheiden — dann bleibt die kurze Schreibweise stehen statt sich in
    /// einen absoluten Pfad zu verwandeln, der genauso ins Leere zeigt.
    /// </summary>
    [Fact]
    public async Task StelleUm_LaesstEinenUnauffindbarenBestandInRuhe()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Nirgends",
            WordFilePathOhneAuflistung = "Anspruch.docx",
            WordFilePathMitAuflistung = null,
        });
        await _db.SaveChangesAsync();

        var geaendert = await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\A\Vorlagen", @"C:\B\Vorlagen", NurDiese(), CancellationToken.None);
        _db.ChangeTracker.Clear();

        geaendert.Should().Be(0);
        var vorlage = await _db.FormTemplates.SingleAsync(t => t.Id == 1);
        vorlage.WordFilePathOhneAuflistung.Should().Be("Anspruch.docx");
    }

    /// <summary>
    /// Zieht der Anwalt die Dateien mit, wird aus dem Bestand wieder eine kurze
    /// Schreibweise — relativ zum neuen Ordner, nicht der absolute Umweg.
    /// </summary>
    [Fact]
    public async Task StelleUm_BleibtRelativWennDerBestandMitwandert()
    {
        _db.FormTemplates.Add(new FormTemplateEntity
        {
            Id = 1,
            TemplateName = "Wandert mit",
            WordFilePathOhneAuflistung = @"C:\B\Vorlagen\Anspruch.docx",
            WordFilePathMitAuflistung = null,
        });
        await _db.SaveChangesAsync();

        await VorlagenPfadUmstellung.StelleUmAsync(
            _db, @"C:\A\Vorlagen", @"C:\B\Vorlagen", CancellationToken.None);
        _db.ChangeTracker.Clear();

        var vorlage = await _db.FormTemplates.SingleAsync(t => t.Id == 1);
        vorlage.WordFilePathOhneAuflistung.Should().Be("Anspruch.docx");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
