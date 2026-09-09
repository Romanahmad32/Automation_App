using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.HostedServices;

namespace AutomationService.Features.Vorgaenge.Presentation.DependencyInjection;

public static class VorgaengeInjection
{
    public static IServiceCollection AddVorgaengeServices(this IServiceCollection services)
    {
        services.AddScoped<IVorgangRepository, VorgangRepository>();
        services.AddScoped<IVorgangAbschlussService, VorgangAbschlussService>();

        // Kein eigenes Interface: Die Löschung hat eine einzige Umsetzung und
        // wird nur vom Controller aufgerufen, anders als die Repositories und
        // Dienste darüber, die auch aus anderen Slices heraus ausgetauscht
        // werden könnten.
        services.AddScoped<VorgangLoeschung>();

        // Bauordner und Stand haengen an festen Pfaden und halten keinen
        // Zustand je Anfrage — Singleton. Beide liegen neben der Datenbank und
        // nicht im Ablageordner: Was dort landet, synchronisiert mit und waere
        // auf dem Handy als Fremddatei sichtbar.
        services.AddSingleton(_ => new RegisterSpiegelBauordner(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "RegisterBau")));
        services.AddSingleton(_ => new RegisterSpiegelStand(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "register-spiegel.stand.json")));

        // Die Schleuse muss Singleton sein, sonst schleust sie nichts: Zwei
        // Anfragen bekaemen je ihre eigene und liefen wieder gleichzeitig.
        services.AddSingleton<RegisterSpiegelSchleuse>();
        services.AddScoped<IRegisterSpiegelService, RegisterSpiegelService>();

        // Die Zeilen der Ansicht: dieselbe Fachlogik wie der Spiegel, aber ohne
        // Word, PDF und Ablageordner — der Bildschirm soll nichts davon
        // aufwecken.
        services.AddScoped<IRegisterZeilenDienst, RegisterZeilenDienst>();

        // Der Nachzug der PDF-Fassung (§6.2 „Word sofort, PDF nachgezogen") ist
        // ein Hintergrunddienst und kein abgesetzter Task: Der Scoped-DbContext
        // des Aufrufs ist nach der Antwort tot, im Auftrag stehen deshalb nur
        // Pfade. Die Warteschlange muss Singleton sein — je Anfrage eine eigene
        // wäre keine Warteschlange —, und der Hintergrunddienst muss dieselbe
        // Instanz sehen wie der Schreiblauf, der einreiht.
        services.AddSingleton<RegisterPdfWarteschlange>();
        services.AddSingleton<IRegisterPdfWarteschlange>(sp =>
            sp.GetRequiredService<RegisterPdfWarteschlange>());
        services.AddHostedService<RegisterPdfNachzug>();

        return services;
    }
}
