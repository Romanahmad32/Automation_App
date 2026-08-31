using AutomationService.Core.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sichert den Seed des Sachgebietskatalogs (§7.1) gegen stilles Auseinanderlaufen
/// mit dem Anforderungsdokument: Die zwölf Kürzel stehen dort wortwörtlich, und
/// ein Tippfehler im Seed fiele sonst erst dem Anwalt auf — als Abteilung, nach
/// der niemand filtern kann. Geprüft werden außerdem die Invarianten, an denen
/// die Referenz-Zerlegung hängt: kein leeres Kürzel, keins mit Leerzeichen.
/// </summary>
public sealed class SachgebietKatalogTests : IDisposable
{
    private static readonly string[] KatalogKuerzel =
        ["C01", "C01a", "C02", "C03", "C03o", "C04", "C05", "C06", "C06a", "C06s", "C07", "C07m"];

    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly SachgebietKatalog _katalog;

    public SachgebietKatalogTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        // EnsureCreated legt das Schema samt HasData-Seed an — derselbe Bestand,
        // den die Migration beim Anwender einspielt.
        _db.Database.EnsureCreated();
        _katalog = new SachgebietKatalog(_db);
    }

    [Fact]
    public async Task Seed_EnthaeltGenauDieZwoelfKuerzelDesKatalogs_InKatalogreihenfolge()
    {
        var eintraege = await _katalog.GetAllAsync(CancellationToken.None);

        eintraege.Select(s => s.Kuerzel).Should().Equal(
            KatalogKuerzel,
            "der Seed muss dem Katalog in §7.1 wortwörtlich entsprechen — " +
            "Vertragsrecht bleibt draußen, es hat kein Kürzel");
    }

    [Fact]
    public async Task Seed_KuerzelSindNieLeerUndOhneLeerzeichen()
    {
        var eintraege = await _katalog.GetAllAsync(CancellationToken.None);

        foreach (var eintrag in eintraege)
        {
            eintrag.Kuerzel.Should().NotBeNullOrWhiteSpace(
                "Einträge ohne Kürzel sind nicht erlaubt (§7.1)");
            eintrag.Kuerzel.Should().NotContain(" ",
                "die Referenz-Zerlegung trennt die Abteilung am Leerzeichen (§4.2) — " +
                "ein Kürzel mit Leerzeichen zerfiele dort still");
        }
    }

    [Fact]
    public async Task Seed_JederEintragTraegtNamenUndRechtsgebietVorschlag()
    {
        var eintraege = await _katalog.GetAllAsync(CancellationToken.None);

        foreach (var eintrag in eintraege)
        {
            eintrag.Name.Should().NotBeNullOrWhiteSpace();
            eintrag.RechtsgebietVorschlag.Should().NotBeNullOrWhiteSpace();
            eintrag.Aktiv.Should().BeTrue("der Seed enthält nur den gültigen Katalog");
        }

        // Die eine Stelle, an der Vorschlag und Name auseinanderliegen: Die
        // Sachgebietsspalte schreibt "Zivilrecht", der Katalogname trägt den
        // Zusatz "(allgemein)".
        var zivilrecht = eintraege.Single(s => s.Kuerzel == "C01");
        zivilrecht.Name.Should().Be("Zivilrecht (allgemein)");
        zivilrecht.RechtsgebietVorschlag.Should().Be("Zivilrecht");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
