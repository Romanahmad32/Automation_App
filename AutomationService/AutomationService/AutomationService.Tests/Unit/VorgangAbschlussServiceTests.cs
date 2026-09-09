using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft den atomaren Vorgangsabschluss (§4.8, §7.1) gegen eine echte
/// In-Memory-SQLite: Statuswechsel und Auftragsnummer hängen zusammen, doppeltes
/// Abschließen zählt nicht doppelt, unbekannte Referenzen ändern nichts.
/// </summary>
public sealed class VorgangAbschlussServiceTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VorgangAbschlussService _service;
    private readonly RegisterSpiegelAttrappe _spiegel = new();
    private readonly AutomatischeSicherungAttrappe _sicherung = new();

    /// <summary>
    /// Ein winziger Container, nur damit es eine <c>IServiceScopeFactory</c>
    /// gibt. Der Abschluss holt den Spiegel seit §4.8 aus einem eigenen Scope:
    /// Er stösst ihn abgesetzt an, und der DbContext des Requests ist zu diesem
    /// Zeitpunkt schon abgeräumt. Die Attrappe liegt als Singleton darin, damit
    /// der Test hinterher dieselbe befragen kann, die der Dienst aufgerufen hat.
    /// </summary>
    private readonly ServiceProvider _dienste;

    public VorgangAbschlussServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _dienste = new ServiceCollection()
            .AddSingleton<IRegisterSpiegelService>(_spiegel)
            .BuildServiceProvider();
        _service = new VorgangAbschlussService(
            _db,
            _dienste.GetRequiredService<IServiceScopeFactory>(),
            _sicherung,
            NullLogger<VorgangAbschlussService>.Instance);
    }

    private async Task<VorgangEntity> LegeVorgangAn(string referenz, string status = "abgelegt")
    {
        var vorgang = new VorgangEntity
        {
            Referenz = referenz,
            AngefragtAm = new DateTime(2026, 6, 1),
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
        };
        _db.Vorgaenge.Add(vorgang);
        await _db.SaveChangesAsync();
        return vorgang;
    }

    private async Task LegeSettingsAn(int laufendeNummer, bool spiegelSchreiben = false)
    {
        _db.KanzleiSettings.Add(new KanzleiSettingsEntity
        {
            LaufendeAuftragsnummer = laufendeNummer,
            RegisterNachAbschlussSchreiben = spiegelSchreiben,
        });
        await _db.SaveChangesAsync();
    }

    [Fact]
    public async Task Abschliessen_SetztStatusUndZaehltNummerHoch()
    {
        await LegeSettingsAn(84);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
        ergebnis.AbgeschlossenAm.Should().NotBeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(85);
    }

    [Fact]
    public async Task Abschliessen_BereitsVersendet_ZaehltNichtErneut()
    {
        await LegeSettingsAn(85);
        await LegeVorgangAn("84/26 C03_GG-XY 123", status: VorgangAbschlussService.StatusVersendet);

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(85);
    }

    [Fact]
    public async Task Abschliessen_UnbekannteReferenz_LiefertNullUndAendertNichts()
    {
        await LegeSettingsAn(84);

        var ergebnis = await _service.AbschliessenAsync("99/26 C03_XX-YY 1");

        ergebnis.Should().BeNull();
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(84);
    }

    [Fact]
    public async Task Abschliessen_OhneSettings_LegtDefaultsAnUndZaehltHoch()
    {
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        // Default ist 1, das Inkrement macht daraus 2.
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(2);
    }

    [Fact]
    public async Task Abschliessen_TrimmtDieReferenz()
    {
        await LegeSettingsAn(84);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        var ergebnis = await _service.AbschliessenAsync("  84/26 C03_GG-XY 123  ");

        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
    }

    /// <summary>
    /// Der Spiegel wird nachgezogen (§6.2, #40) — aber abgesetzt (§4.8).
    /// Deshalb wird auf den Wartepunkt der Attrappe gewartet und nicht bloss
    /// ihr Zähler gelesen; sonst hinge der Test daran, wie der Planer die
    /// Aufgabe gelegt hat.
    /// </summary>
    [Fact]
    public async Task Abschliessen_ZiehtDenRegisterSpiegelNach()
    {
        await LegeSettingsAn(84, spiegelSchreiben: true);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        await _spiegel.Angestossen.WaitAsync(TimeSpan.FromSeconds(5));
        _spiegel.Aufrufe.Should().Be(1);
    }

    /// <summary>
    /// Die Zusicherung aus §4.8: Der Abschluss wartet nicht darauf, dass die
    /// Register-Dateien geschrieben sind. Beim Bestand der Kanzlei kostete das
    /// Warten 20 Sekunden — ein Abschluss, der 20 Sekunden hängt, ist kein
    /// Abschluss, den man drückt.
    ///
    /// Gezeigt an einem Spiegel, der nicht durchkommt: Wartete der Abschluss,
    /// käme er selbst nicht zurück und der Test liefe in seine Zeitgrenze.
    /// </summary>
    [Fact]
    public async Task Abschliessen_WartetNichtAufDenRegisterSpiegel()
    {
        await LegeSettingsAn(84, spiegelSchreiben: true);
        await LegeVorgangAn("84/26 C03_GG-XY 123");
        _spiegel.Anhalten();

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
        // Angestossen wird er trotzdem — nur eben danach.
        await _spiegel.Angestossen.WaitAsync(TimeSpan.FromSeconds(5));
        _spiegel.Freigeben();
    }

    /// <summary>
    /// Nach dem Abschluss geht der Stand in den synchronisierten Ordner (#39).
    /// Der Abschluss wartet dabei ausdrücklich <em>nicht</em> — deshalb wird auf
    /// die Attrappe gewartet und nicht bloss ihr Zähler gelesen.
    /// </summary>
    [Fact]
    public async Task Abschliessen_StoesstDieAutomatischeSicherungAn()
    {
        await LegeSettingsAn(84);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        await _sicherung.Angestossen.WaitAsync(TimeSpan.FromSeconds(5));
        _sicherung.Aufrufe.Should().Be(1);
    }

    [Fact]
    public async Task Abschliessen_LaesstDenSpiegelWeg_WennDerSchalterAusIst()
    {
        await LegeSettingsAn(84, spiegelSchreiben: false);
        await LegeVorgangAn("84/26 C03_GG-XY 123");

        await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        _spiegel.Aufrufe.Should().Be(0);
    }

    /// <summary>
    /// Die eigentliche Zusicherung der Reihenfolge (§6.2, #40): Der Spiegel
    /// läuft nach dem Commit. Ein gesperrter Ablageordner, ein fehlendes Word
    /// oder ein volles Laufwerk dürfen einen abgeschlossenen Auftrag nicht
    /// wieder aufmachen — der Spiegel ist eine Kopie, die Datenbank ist das
    /// Register.
    /// </summary>
    [Fact]
    public async Task Abschliessen_BleibtBestehen_WennDerSpiegelScheitert()
    {
        await LegeSettingsAn(84, spiegelSchreiben: true);
        await LegeVorgangAn("84/26 C03_GG-XY 123");
        _spiegel.Wirft = new IOException("Der Ablageordner ist nicht erreichbar.");

        var ergebnis = await _service.AbschliessenAsync("84/26 C03_GG-XY 123");

        // Gewartet wird auf den Wartepunkt, damit die Ausnahme wirklich
        // gefallen ist, bevor der Test nachsieht — sie fällt seit §4.8 in einer
        // abgesetzten Aufgabe.
        await _spiegel.Angestossen.WaitAsync(TimeSpan.FromSeconds(5));
        ergebnis.Should().NotBeNull();
        ergebnis!.Status.Should().Be(VorgangAbschlussService.StatusVersendet);
        (await _db.KanzleiSettings.SingleAsync()).LaufendeAuftragsnummer.Should().Be(85);
    }

    public void Dispose()
    {
        _spiegel.Dispose();
        _dienste.Dispose();
        _db.Dispose();
        _connection.Dispose();
    }
}
