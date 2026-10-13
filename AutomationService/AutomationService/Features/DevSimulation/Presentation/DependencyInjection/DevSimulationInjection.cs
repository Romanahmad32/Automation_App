using AutomationService.Core.Persistence;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace AutomationService.Features.DevSimulation.Presentation.DependencyInjection;

public static class DevSimulationInjection
{
    /// <summary>
    /// Bindet <see cref="SimulationOptions"/> und schaltet — nur mit
    /// <c>Simulation:Testmodus</c> — den E2E-Testmodus ein (#168): Alle Nähte,
    /// über die die App nach außen wirkt, gehen auf Attrappen.
    ///
    /// <b>Muss der letzte Add…-Aufruf in Program.cs bleiben.</b> Ersetzen lässt
    /// sich nur, was schon registriert ist; ein später registrierter echter
    /// Dienst stünde wieder daneben. Ersetzt wird mit <c>RemoveAll</c> und
    /// nicht mit <c>Replace</c> — das nähme nur den ersten Eintrag.
    /// </summary>
    /// <param name="services">Die Registrierungen der App.</param>
    /// <param name="configuration">Gelesen wird hier, bei der Registrierung — nicht erst über die Options.</param>
    /// <param name="environment">In Production startet der Testmodus nie.</param>
    /// <param name="datenordnerUmgelenkt">
    /// Ob <c>AppDataPaths</c> umgelenkt ist; ohne Angabe
    /// <see cref="AppDataPaths.IstUmgelenkt"/>. Nur für Tests übergeben: Im
    /// Testlauf ist der Ordner immer umgelenkt, und das prozessweite Static
    /// umzubiegen träfe alle parallel laufenden Tests.
    /// </param>
    public static IServiceCollection AddDevSimulationServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment,
        bool? datenordnerUmgelenkt = null)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(environment);

        var abschnitt = configuration.GetSection(SimulationOptions.SectionName);
        services.AddOptions<SimulationOptions>().Bind(abschnitt);

        var testmodus = abschnitt.Get<SimulationOptions>()?.Testmodus ?? false;
        if (testmodus)
        {
            PruefeTestmodus(environment, datenordnerUmgelenkt ?? AppDataPaths.IstUmgelenkt);
            ErsetzeNaehte(services);
        }

        // Der Wert, den /health meldet, ist der hier entschiedene. Ein
        // WebApplicationFactory-Test reicht Konfiguration über
        // ConfigureAppConfiguration erst nach der Registrierung herein — ohne
        // diese Zeile meldete /health dann einen Testmodus, dessen Attrappen
        // nie registriert wurden, und die App übernähme den Dienst.
        services.PostConfigure<SimulationOptions>(optionen => optionen.Testmodus = testmodus);

        return services;
    }

    /// <summary>
    /// Der Testmodus ersetzt die Wirkung nach außen, nicht die Daten — die
    /// liegen dort, wohin der Datenordner zeigt. Zeigte er auf %APPDATA%,
    /// spielte ein Testlauf mit dem echten Bestand der Kanzlei. Und die
    /// installierte App hat im Testmodus nichts verloren, egal, wer den
    /// Schalter gesetzt hat.
    /// </summary>
    private static void PruefeTestmodus(IHostEnvironment environment, bool datenordnerUmgelenkt)
    {
        if (environment.IsProduction())
        {
            throw new InvalidOperationException(
                "Simulation:Testmodus ist eingeschaltet, die Umgebung ist aber Production. "
                + "Die installierte App läuft nie im Testmodus — der Dienst startet nicht. "
                + "Für den E2E-Testmodus mit --environment E2E und --Datenordner <pfad> starten "
                + "(scripts/e2e-start.ps1).");
        }

        if (!datenordnerUmgelenkt)
        {
            throw new InvalidOperationException(
                "Simulation:Testmodus ist eingeschaltet, der Datenordner zeigt aber auf den echten "
                + $"Bestand (%APPDATA%\\AutomationService). Ohne „--{AppDataPaths.DatenordnerSchluessel} <pfad>“ "
                + "startet der Testmodus nicht — sonst spielte der Testlauf mit den Daten der Kanzlei.");
        }
    }

    private static void ErsetzeNaehte(IServiceCollection services)
    {
        // Der Ordner wird erst bei der ersten Auflösung bestimmt, also nach
        // Program.cs' Zuweisung des Datenordners.
        services.AddSingleton(_ => new TestmodusOrdner(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "Testmodus")));
        services.AddSingleton<TestmodusProtokoll>();

        // Dieselben Lebensdauern wie die echten Dienste: Wer sie verwendet,
        // merkt keinen Unterschied — auch nicht die Bereichsprüfung, die in
        // Development einen Singleton ablehnt, der einen Scoped-Dienst hält.
        services.RemoveAll<IZentralrufAutomationService>();
        services.AddSingleton<IZentralrufAutomationService, TestmodusZentralruf>();
        services.RemoveAll<ISmtpUebergabe>();
        services.AddScoped<ISmtpUebergabe, TestmodusSmtpUebergabe>();
        services.RemoveAll<IGesendetOrdnerAblage>();
        services.AddScoped<IGesendetOrdnerAblage, TestmodusGesendetAblage>();
        services.RemoveAll<IOutlookVerbindung>();
        services.AddSingleton<IOutlookVerbindung, TestmodusOutlook>();
        services.RemoveAll<IEntwurfDatei>();
        services.AddScoped<IEntwurfDatei, TestmodusEntwurfDatei>();
        services.RemoveAll<IWordDrucker>();
        services.AddSingleton<IWordDrucker, TestmodusWordDrucker>();
        services.RemoveAll<IDruckerAuskunft>();
        services.AddSingleton<IDruckerAuskunft, TestmodusDruckerAuskunft>();
    }
}
