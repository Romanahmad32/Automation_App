using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.HostedServices;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Schutzregel des Vollmacht-Saatguts (§4.11): Ein Muster trägt keinen
/// Kanzleikopf. Es darf nur in den App-eigenen Vorlagenordner — läge es unter
/// dem festen Namen im Ordner, den der Anwalt gewählt hat, druckte die App
/// eine Vollmacht ohne Bevollmächtigten. Das Kopieren selbst (überschreibt
/// nie) prüft <see cref="VollmachtVorlagenOrdnerTests"/>.
/// </summary>
public sealed class VollmachtVorlagenSeedServiceTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtSaat_{Guid.NewGuid():N}");

    public VollmachtVorlagenSeedServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options);
        _db.Database.EnsureCreated();
    }

    private string VollmachtOrdner => Path.Combine(_vorlagenOrdner, VollmachtArten.Unterordner);

    [Fact]
    public async Task Ohne_eingestellten_Ordner_kommen_die_drei_Muster_in_den_App_Ordner()
    {
        await Starte();

        Directory.GetFiles(VollmachtOrdner).Select(Path.GetFileName)
            .Should().BeEquivalentTo(VollmachtArten.Alle.Select(VollmachtArten.Dateiname));
    }

    [Fact]
    public async Task In_einen_gewaehlten_Vorlagenordner_kommt_kein_Muster()
    {
        SpeichereEinstellung(satz => satz.VorlagenOrdner = _vorlagenOrdner);

        await Starte();

        LiegtNichts();
    }

    /// <summary>
    /// Seit #103 gilt auch der aus dem App-Daten-Ordner abgeleitete
    /// Vorlagenordner als vom Anwalt bestimmt.
    /// </summary>
    [Fact]
    public async Task In_einen_abgeleiteten_Vorlagenordner_kommt_kein_Muster()
    {
        SpeichereEinstellung(satz => satz.AppDatenOrdner = _vorlagenOrdner);

        await Starte();

        LiegtNichts();
    }

    private async Task Starte()
    {
        await using var dienste = new ServiceCollection()
            .AddSingleton(_db)
            .AddScoped(_ => new VollmachtVorlagenOrdner(
                _vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance))
            .BuildServiceProvider();

        var saat = new VollmachtVorlagenSeedService(
            dienste.GetRequiredService<IServiceScopeFactory>(),
            Options.Create(new WordAutomationOptions()),
            new FakeHostEnvironment(Path.Combine(RepoWurzel.Pfad(), "AutomationService", "AutomationService")),
            NullLogger<VollmachtVorlagenSeedService>.Instance);
        await saat.StartAsync(CancellationToken.None);
    }

    private void LiegtNichts() =>
        (Directory.Exists(VollmachtOrdner) ? Directory.GetFiles(VollmachtOrdner) : [])
            .Should().BeEmpty();

    private void SpeichereEinstellung(Action<KanzleiSettingsEntity> setze)
    {
        var satz = KanzleiSettingsRepository.CreateDefault();
        setze(satz);
        _db.KanzleiSettings.Add(satz);
        _db.SaveChanges();
        _db.ChangeTracker.Clear();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }
}
