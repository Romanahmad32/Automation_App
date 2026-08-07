using System.Globalization;
using System.Reflection;

namespace AutomationService.Core.Lifetime;

/// <summary>
/// Verdrahtet alles, was den Lebenszyklus des Dienstes als Teil der
/// Desktop-Anwendung betrifft: das Bereitschaftssignal, den Health-Endpunkt
/// und den Waechter auf den Elternprozess. Folgt dem Add…Services-Muster der
/// Features.
/// </summary>
public static class LifetimeInjection
{
    /// <summary>
    /// Aufrufparameter, mit dem das Frontend seine eigene Prozess-ID
    /// uebergibt. Fehlt er, laeuft der Dienst eigenstaendig (Entwicklung).
    /// </summary>
    public const string ParentPidArgument = "parent-pid";

    public static IServiceCollection AddLifetimeServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton<ApplicationReadiness>();

        var parentPid = configuration[ParentPidArgument];
        if (int.TryParse(parentPid, CultureInfo.InvariantCulture, out var pid) && pid > 0)
        {
            services.AddHostedService(provider => new ParentProcessWatchdog(
                pid,
                provider.GetRequiredService<IHostApplicationLifetime>(),
                provider.GetRequiredService<ILogger<ParentProcessWatchdog>>()));
        }

        return services;
    }

    /// <summary>
    /// Meldet den Startzustand des Dienstes: 200 mit <c>bereit</c>, sobald der
    /// Start durch ist, sonst 503 mit <c>startet</c>. Das Frontend pollt diesen
    /// Endpunkt, bis er 200 liefert, und zeigt erst dann die Oberflaeche.
    ///
    /// Bewusst ohne Authentifizierung und ohne Nutzdaten: der Dienst lauscht
    /// nur auf localhost, und die Antwort verraet nichts, was nicht ohnehin in
    /// der Fensterleiste steht.
    /// </summary>
    public static void MapHealthEndpoint(this WebApplication app)
    {
        var readiness = app.Services.GetRequiredService<ApplicationReadiness>();
        var version = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? "unbekannt";

        app.MapGet("/health", () => readiness.IstBereit
            ? Results.Ok(new HealthAntwort("bereit", version))
            : Results.Json(
                new HealthAntwort("startet", version),
                statusCode: StatusCodes.Status503ServiceUnavailable));

        // Feuert erst, wenn alle Hosted Services ihr StartAsync beendet haben —
        // also nach Migration und Alt-Import. Genau das ist "bereit".
        app.Lifetime.ApplicationStarted.Register(readiness.MarkiereBereit);
    }
}
