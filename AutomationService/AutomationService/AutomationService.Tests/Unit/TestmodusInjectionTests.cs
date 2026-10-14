using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.DependencyInjection;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.DevSimulation.Presentation.DependencyInjection;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.DependencyInjection;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.PdfConversion.Presentation.DependencyInjection;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Presentation.DependencyInjection;
using AutomationService.Tests.Architecture;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Verdrahtung des E2E-Testmodus (#168), ohne Host geprüft: Ohne den
/// Schalter bleibt jede der zehn Nähte nach außen echt, mit ihm geht jede
/// auf ihre Attrappe — und in Production oder ohne umgelenkten Datenordner
/// startet der Testmodus gar nicht.
///
/// Registriert werden die echten Slices davor, wie in <c>Program.cs</c>: Ob
/// <c>RemoveAll</c> greift, sieht man nur, wenn vorher etwas da war.
/// </summary>
public sealed class TestmodusInjectionTests
{
    /// <summary>Naht, Lebensdauer, echter Typ (null = Fabrik), Attrappe.</summary>
    public static TheoryData<Type, ServiceLifetime, Type?, Type> Naehte => new()
    {
        { typeof(IZentralrufAutomationService), ServiceLifetime.Singleton, typeof(ZentralrufAutomationService), typeof(TestmodusZentralruf) },
        { typeof(ISmtpUebergabe), ServiceLifetime.Scoped, typeof(SmtpUebergabe), typeof(TestmodusSmtpUebergabe) },
        { typeof(IGesendetOrdnerAblage), ServiceLifetime.Scoped, typeof(GesendetOrdnerAblage), typeof(TestmodusGesendetAblage) },
        { typeof(IOutlookVerbindung), ServiceLifetime.Singleton, typeof(OutlookVerbindung), typeof(TestmodusOutlook) },
        { typeof(IEntwurfDatei), ServiceLifetime.Scoped, typeof(EntwurfDatei), typeof(TestmodusEntwurfDatei) },
        { typeof(IWordDrucker), ServiceLifetime.Singleton, null, typeof(TestmodusWordDrucker) },
        { typeof(IDruckerAuskunft), ServiceLifetime.Singleton, typeof(WindowsDruckerAuskunft), typeof(TestmodusDruckerAuskunft) },
        { typeof(IAktualisierungsQuelle), ServiceLifetime.Singleton, typeof(GithubAktualisierungsQuelle), typeof(TestmodusAktualisierungsQuelle) },
        { typeof(IInstallerStarter), ServiceLifetime.Singleton, typeof(InstallerStarter), typeof(TestmodusInstallerStarter) },
        { typeof(IHerunterfahrenNachInstallerStart), ServiceLifetime.Singleton, typeof(GeordnetesHerunterfahren), typeof(TestmodusHerunterfahren) },
    };

    private static ServiceCollection Registrierungen(
        bool testmodus,
        string umgebung = "E2E",
        bool datenordnerUmgelenkt = true)
    {
        var konfiguration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Simulation:Testmodus"] = testmodus ? "true" : "false",
            })
            .Build();

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddPdfConversionServices(konfiguration);
        services.AddZentralrufServices(konfiguration);
        services.AddEmailVersandServices(konfiguration);
        services.AddAktualisierungServices(konfiguration);
        services.AddDevSimulationServices(
            konfiguration,
            new FakeHostEnvironment(Path.GetTempPath()) { EnvironmentName = umgebung },
            datenordnerUmgelenkt);
        return services;
    }

    [Theory]
    [MemberData(nameof(Naehte))]
    public void Ohne_Testmodus_bleibt_die_Naht_echt(Type naht, ServiceLifetime lebensdauer, Type? echt, Type attrappe)
    {
        var eintrag = Registrierungen(testmodus: false).Where(d => d.ServiceType == naht)
            .Should().ContainSingle().Subject;

        eintrag.Lifetime.Should().Be(lebensdauer);
        eintrag.ImplementationType.Should().Be(echt).And.NotBe(attrappe);
        if (echt is null)
        {
            eintrag.ImplementationFactory.Should().NotBeNull("der echte Drucker ist die Instanz des Word-Threads");
        }
    }

    [Theory]
    [MemberData(nameof(Naehte))]
    public void Mit_Testmodus_loest_die_Naht_zur_Attrappe_auf(Type naht, ServiceLifetime lebensdauer, Type? echt, Type attrappe)
    {
        var services = Registrierungen(testmodus: true);

        services.Where(d => d.ServiceType == naht).Should().ContainSingle(
            "RemoveAll statt Replace: neben der Attrappe darf kein echter Dienst stehen bleiben, "
            + "den ein IEnumerable-Verbraucher doch noch erreicht")
            .Which.Lifetime.Should().Be(lebensdauer, $"die Attrappe lebt so lange wie {echt?.Name ?? "die echte Fabrik"}");

        using var anbieter = services.BuildServiceProvider(validateScopes: true);
        using var bereich = anbieter.CreateScope();
        bereich.ServiceProvider.GetRequiredService(naht).Should().BeOfType(attrappe);
    }

    /// <summary>
    /// Nach dem Installer-Start (#196): Ohne Testmodus fährt der Dienst nach der
    /// Verzögerung herunter, im Testmodus nie — dort startet kein Setup, und die
    /// Suite fährt weitere Durchläufe gegen denselben Dienst. Aufgelöst wie in der
    /// App, nur mit Uhr und Lebensdauer als Attrappen.
    /// </summary>
    [Theory]
    [InlineData(false, 1)]
    [InlineData(true, 0)]
    public async Task Nach_dem_Installer_Start_faehrt_nur_der_echte_Dienst_herunter(bool testmodus, int stopps)
    {
        var uhr = new HandUhr();
        using var lebensdauer = new LebensdauerAttrappe();
        var services = Registrierungen(testmodus);
        services.AddSingleton<TimeProvider>(uhr);
        services.AddSingleton<IHostApplicationLifetime>(lebensdauer);
        using var anbieter = services.BuildServiceProvider(validateScopes: true);

        anbieter.GetRequiredService<IHerunterfahrenNachInstallerStart>().StoesseAn();
        uhr.Vorstellen(TimeSpan.FromMinutes(1));

        if (stopps > 0)
        {
            await lebensdauer.Gestoppt.WaitAsync(TimeSpan.FromSeconds(10));
        }

        lebensdauer.Stopps.Should().Be(stopps);
    }

    [Fact]
    public void Mit_Testmodus_meldet_die_Option_ihn()
    {
        using var anbieter = Registrierungen(testmodus: true).BuildServiceProvider();

        anbieter.GetRequiredService<IOptions<SimulationOptions>>().Value.Testmodus.Should().BeTrue();
    }

    /// <summary>
    /// /health meldet, was bei der Registrierung entschieden wurde. Kommt der
    /// Schalter erst danach herein (so reicht <c>ConfigureAppConfiguration</c>
    /// ihn in einem Testhost nach), stünden sonst echte Dienste hinter einem
    /// Dienst, der „Testmodus" meldet.
    /// </summary>
    [Fact]
    public void Ein_spaeter_gesetzter_Schalter_aendert_die_Meldung_nicht()
    {
        var services = Registrierungen(testmodus: false);
        services.Configure<SimulationOptions>(optionen => optionen.Testmodus = true);

        using var anbieter = services.BuildServiceProvider();

        anbieter.GetRequiredService<IOptions<SimulationOptions>>().Value.Testmodus.Should().BeFalse();
    }

    [Fact]
    public void In_Production_bricht_der_Testmodus_den_Start_ab()
    {
        var registrieren = () => Registrierungen(testmodus: true, umgebung: Environments.Production);

        registrieren.Should().Throw<InvalidOperationException>().WithMessage("*Production*");
    }

    [Fact]
    public void Ohne_umgelenkten_Datenordner_bricht_der_Testmodus_den_Start_ab()
    {
        var registrieren = () => Registrierungen(testmodus: true, umgebung: Environments.Development, datenordnerUmgelenkt: false);

        registrieren.Should().Throw<InvalidOperationException>().WithMessage("*Datenordner*");
    }

    [Fact]
    public void Ohne_Testmodus_startet_Production_wie_immer()
    {
        var registrieren = () => Registrierungen(testmodus: false, umgebung: Environments.Production, datenordnerUmgelenkt: false);

        registrieren.Should().NotThrow();
    }

    /// <summary>
    /// Was nicht im Code einer Attrappe steht, kann sie nicht auslösen: kein
    /// Prozessstart (Mailprogramm, Installer), kein COM (Outlook, Word), kein
    /// Browser, kein Mailserver, kein HTTP (Update-Quelle, #196), kein
    /// Herunterfahren des Dienstes (#196). Kommentare zählen nicht mit — dort
    /// darf stehen, was die Attrappe gerade <i>nicht</i> tut.
    /// </summary>
    [Fact]
    public void Keine_Attrappe_greift_nach_aussen()
    {
        string[] verboten = ["Process.Start", "GetTypeFromProgID", "Playwright", "SmtpClient", "ImapClient", "PrintOut", "HttpClient", "StopApplication"];

        var attrappen = CsQuelldateien.InFeatures()
            .Where(datei => datei.RelativerPfad.StartsWith("/Features/DevSimulation/Domain/Services/Testmodus", StringComparison.Ordinal))
            .ToList();

        attrappen.Should().HaveCountGreaterThanOrEqualTo(9, "die neun Testmodus-Bausteine sind gemeint");
        attrappen
            .SelectMany(datei => File.ReadAllLines(datei.AbsoluterPfad)
                .Where(Quelldatei.IstAnweisungszeile)
                .SelectMany(zeile => verboten.Where(wort => zeile.Contains(wort, StringComparison.Ordinal)))
                .Select(wort => $"{datei.RelativerPfad}: {wort}"))
            .Should().BeEmpty();
    }
}
