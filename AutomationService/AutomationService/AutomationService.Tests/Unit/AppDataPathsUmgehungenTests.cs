using AutomationService.Core.Persistence;
using AutomationService.Core.Persistence.HostedServices;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Tests.Architecture;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die zwei Stellen, die einmal an <see cref="AppDataPaths"/> vorbei in den
/// echten Bestand griffen (#168): der Altdatenimport und der MSAL-Cache.
/// Im Testlauf ist der Datenordner immer umgelenkt (<c>WurzelFuerTests</c>) —
/// genau der Fall, den der E2E-Dienst mit <c>--Datenordner</c> hat.
/// </summary>
public sealed class AppDataPathsUmgehungenTests
{
    /// <summary>
    /// Der Import benennt Quelldateien um — bei umgelenktem Ordner darf er
    /// den echten Flutter-Ordner weder lesen noch anfassen. Die Meldung
    /// belegt, dass er die Prüfung erreicht hat und nicht zufällig nichts fand.
    /// </summary>
    [Fact]
    public async Task Der_Altdatenimport_liest_bei_umgelenktem_Ordner_ohne_Quellordner_nichts()
    {
        var logger = new ListenLogger<LegacyJsonImportService>();
        var dienst = Importdienst(logger, new Dictionary<string, string?> { ["LegacyImport:Enabled"] = "true" });

        await dienst.StartAsync(CancellationToken.None);

        AppDataPaths.IstUmgelenkt.Should().BeTrue("so läuft jeder Test");
        logger.Nachrichten.Should().ContainSingle().Which.Should().Contain("umgelenkt");
    }

    /// <summary>Die Gegenprobe: Ein ausdrücklich genannter Quellordner gilt auch bei umgelenktem Ordner.</summary>
    [Fact]
    public async Task Ein_ausdruecklicher_Quellordner_gilt_auch_bei_umgelenktem_Ordner()
    {
        var logger = new ListenLogger<LegacyJsonImportService>();
        var fehlend = Path.Combine(Path.GetTempPath(), "AutomationService.Tests", $"kein_{Guid.NewGuid():N}");
        var dienst = Importdienst(logger, new Dictionary<string, string?>
        {
            ["LegacyImport:Enabled"] = "true",
            ["LegacyImport:SourceDirectory"] = fehlend,
        });

        await dienst.StartAsync(CancellationToken.None);

        logger.Nachrichten.Should().ContainSingle().Which.Should().Contain("Kein Alt-Datenstand").And.Contain(fehlend);
    }

    [Fact]
    public void Der_MSAL_Cache_liegt_im_Datenordner()
    {
        var ordner = MicrosoftMailOAuthService.CacheOrdner();

        ordner.Should().Be(AppDataPaths.EnsureAppDataDirectory());
        var echt = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AutomationService");
        ordner.Should().NotBe(echt, "im Test zeigt der Datenordner ins Temp, nie auf den Bestand der Kanzlei");
    }

    /// <summary>
    /// Der Pfad wird in <c>GetAppAsync</c> gebildet, die ohne Azure-Anmeldung
    /// nicht läuft — deshalb sichert dieser Test die Quelle ab: Wer dort wieder
    /// selbst <c>%APPDATA%</c> auflöst, geht an der Umlenkung vorbei.
    /// </summary>
    [Fact]
    public void Der_MSAL_Dienst_loest_keinen_Systemordner_selbst_auf()
    {
        var quelle = CsQuelldateien.Alle().Single(datei =>
            datei.RelativerPfad.EndsWith("/MicrosoftMailOAuthService.cs", StringComparison.Ordinal));

        File.ReadAllLines(quelle.AbsoluterPfad)
            .Where(Quelldatei.IstAnweisungszeile)
            .Should().NotContain(zeile => zeile.Contains("GetFolderPath", StringComparison.Ordinal))
            .And.Contain(zeile => zeile.Contains("CacheOrdner()", StringComparison.Ordinal));
    }

    private static LegacyJsonImportService Importdienst(
        ListenLogger<LegacyJsonImportService> logger,
        Dictionary<string, string?> werte)
    {
        // Ohne Dienste: Ein Import, der doch loslegte, scheiterte am DbContext.
        var bereiche = new ServiceCollection().BuildServiceProvider().GetRequiredService<IServiceScopeFactory>();
        var konfiguration = new ConfigurationBuilder().AddInMemoryCollection(werte).Build();
        return new LegacyJsonImportService(bereiche, konfiguration, logger);
    }
}
