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
            _db, @"C:\Kanzlei\Vorlagen", CancellationToken.None);
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
            _db, @"C:\Kanzlei\Vorlagen", CancellationToken.None);

        geaendert.Should().Be(0);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
