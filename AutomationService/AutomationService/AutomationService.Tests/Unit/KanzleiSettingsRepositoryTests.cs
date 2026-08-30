using System.Reflection;
using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sichert den Upsert des Einstellungssatzes gegen den Fehler, der hier schon
/// einmal passiert ist: Ein neues Feld kommt in Entity und Dto, aber nicht in
/// <c>CopyInto</c> — und wird beim Speichern über eine bestehende Zeile
/// stillschweigend verworfen. Die Oberfläche meldet dann "gespeichert", der
/// Wert ist beim nächsten Laden trotzdem wieder weg (so geschehen mit
/// <c>MailSignatur</c>, §4.7).
///
/// Die Felder werden deshalb **nicht** einzeln aufgezählt, sondern über
/// Reflexion ermittelt: Wer der Entity eine Eigenschaft hinzufügt, bekommt die
/// Abdeckung ohne Zutun — und einen roten Test, wenn er sie im Upsert vergisst.
/// </summary>
public sealed class KanzleiSettingsRepositoryTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly KanzleiSettingsRepository _repository;

    public KanzleiSettingsRepositoryTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _repository = new KanzleiSettingsRepository(_db);
    }

    [Fact]
    public async Task SaveAsync_UebernimmtJedesFeld_AuchUeberEineBestehendeZeile()
    {
        // Erst anlegen: Der Fehler tritt nur im Zweig für die vorhandene Zeile
        // auf — beim allerersten Speichern wird die Entity komplett eingefügt.
        await _repository.SaveAsync(KanzleiSettingsRepository.CreateDefault());

        var gewuenscht = Gefuellt();
        await _repository.SaveAsync(gewuenscht);
        _db.ChangeTracker.Clear();

        var gelesen = await _repository.GetAsync();
        foreach (var feld in Fachfelder())
        {
            feld.GetValue(gelesen).Should().Be(
                feld.GetValue(gewuenscht),
                "{0} muss in KanzleiSettingsRepository.CopyInto übernommen werden",
                feld.Name);
        }
    }

    [Fact]
    public async Task ErhoeheAuftragsnummerAsync_LaesstDieUebrigenFelderStehen()
    {
        await _repository.SaveAsync(Gefuellt());
        _db.ChangeTracker.Clear();

        await _repository.ErhoeheAuftragsnummerAsync();
        _db.ChangeTracker.Clear();

        var gelesen = await _repository.GetAsync();
        gelesen.LaufendeAuftragsnummer.Should().Be(Zahlwert + 1);
        gelesen.MailSignatur.Should().Be(Textwert(nameof(KanzleiSettingsEntity.MailSignatur)));
        gelesen.Name.Should().Be(Textwert(nameof(KanzleiSettingsEntity.Name)));
    }

    private const int Zahlwert = 4711;

    private static string Textwert(string feldname) => $"Wert von {feldname}";

    /// <summary>Alle beschreibbaren Eigenschaften außer dem festen Schlüssel.</summary>
    private static IEnumerable<PropertyInfo> Fachfelder() =>
        typeof(KanzleiSettingsEntity)
            .GetProperties(BindingFlags.Public | BindingFlags.Instance)
            .Where(eigenschaft => eigenschaft.CanWrite
                && eigenschaft.Name != nameof(KanzleiSettingsEntity.Id));

    /// <summary>
    /// Ein Einstellungssatz, in dem jedes Feld einen eigenen, vom Standardwert
    /// verschiedenen Wert trägt. Ein unbekannter Feldtyp wirft absichtlich:
    /// Dann ist dieser Test zu erweitern, statt das Feld stumm zu übergehen.
    /// </summary>
    private static KanzleiSettingsEntity Gefuellt()
    {
        var entity = new KanzleiSettingsEntity();
        foreach (var feld in Fachfelder())
        {
            if (feld.PropertyType == typeof(string))
            {
                feld.SetValue(entity, Textwert(feld.Name));
            }
            else if (feld.PropertyType == typeof(int))
            {
                feld.SetValue(entity, Zahlwert);
            }
            else if (feld.PropertyType == typeof(bool))
            {
                // true, weil der Standardwert eines bool-Feldes false ist — der
                // Wert muss sich vom Ausgangszustand unterscheiden, sonst ginge
                // ein in CopyInto vergessenes Schaltfeld hier durch.
                feld.SetValue(entity, true);
            }
            else
            {
                throw new NotSupportedException(
                    $"Für {feld.Name} ({feld.PropertyType.Name}) fehlt hier ein Beispielwert.");
            }
        }

        return entity;
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
