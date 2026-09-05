using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.HostedServices;
using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.DependencyInjection;

public static class BackupInjection
{
    /// <summary>
    /// Merker des letzten automatischen Sicherungslaufs (#39). Neben der
    /// Datenbank in %APPDATA% und ausdruecklich nicht darin: Ein Import ersetzt
    /// die Datenbankdatei, und dann waere ausgerechnet die Auskunft weg, ob die
    /// eigene Sicherung zuletzt gelungen ist.
    /// </summary>
    public const string MerkerDateiname = "letzte-sicherung.json";

    /// <summary>
    /// Not-Aus fuer die automatische Sicherung (#39). Wohin sie schreibt, steht
    /// in den App-Einstellungen; dieser Schalter sagt, ob sie ueberhaupt laeuft.
    ///
    /// Er ist kein Zierrat: Ein Testhost faehrt denselben Program.cs gegen
    /// dieselbe Datenbank unter %APPDATA% und legte sonst bei jedem Testlauf
    /// eine echte Sicherung im OneDrive-Ordner des Anwalts ab — samt
    /// Arbeitsplatz-Eintrag, der dem zweiten Rechner einen Stand anbietet, den
    /// niemand gearbeitet hat.
    /// </summary>
    public const string AutomatischeSicherungSchalter = "Backup:AutomatischeSicherung";

    public static IServiceCollection AddBackupServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        // Zustandslos — Singleton. Die Pfade kommen als Zeichenketten statt als
        // Abhängigkeit auf den WordAutomation-Slice: die Sicherung muss die
        // Vorlagen nur finden, nicht verstehen. Der Vorlagenordner ist eine
        // Einstellung (#33), deshalb eine Funktion, die je Operation über einen
        // eigenen Scope aus der Datenbank liest.
        services.AddSingleton<IDatabaseBackupService>(sp =>
            new DatabaseBackupService(
                AppDataPaths.DatabaseFilePath(),
                () => AusDenEinstellungen(sp, VorlagenOrdnerVorgabe.Ermittle),
                sp.GetRequiredService<ILogger<DatabaseBackupService>>()));

        services.AddSingleton(new LetzteSicherungAkte(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), MerkerDateiname)));

        // Fehlt der Eintrag, ist die Sicherung an: Der Normalfall ist die
        // ausgelieferte App, und dort soll sie ohne Zutun laufen.
        var eingeschaltet = configuration.GetValue(AutomatischeSicherungSchalter, defaultValue: true);

        // Derselbe Grund für dieselbe Funktion: Die Sicherungsablage ist eine
        // Einstellung (#39) und wird je Lauf neu aufgelöst. Der Not-Aus hängt an
        // genau dieser Stelle und nicht am Hosted Service — sonst bliebe der
        // zweite Schreibweg offen (die Sicherung nach dem Vorgangsabschluss).
        // Kein Ordner heisst ohnehin: nichts zu tun.
        services.AddSingleton<IAutomatischeSicherung>(sp =>
            new AutomatischeSicherung(
                sp.GetRequiredService<IDatabaseBackupService>(),
                sp.GetRequiredService<LetzteSicherungAkte>(),
                () => eingeschaltet
                    ? AusDenEinstellungen(sp, SicherungsAblageVorgabe.Ermittle)
                    : string.Empty,
                sp.GetRequiredService<ILogger<AutomatischeSicherung>>()));

        // Die Übergabe bleibt auch dann erreichbar: Sie liest nur und spielt
        // ausschliesslich auf Klick ein. Wer die automatische Sicherung
        // abschaltet, will nicht schreiben — nicht blind sein.
        services.AddSingleton<IArbeitsplatzUebergabe>(sp =>
            new ArbeitsplatzUebergabe(
                sp.GetRequiredService<IDatabaseBackupService>(),
                sp.GetRequiredService<LetzteSicherungAkte>(),
                () => AusDenEinstellungen(sp, SicherungsAblageVorgabe.Ermittle),
                sp.GetRequiredService<ILogger<ArbeitsplatzUebergabe>>()));

        services.AddHostedService<ArbeitsplatzDienst>();

        // Der Zeitgeber haengt am Not-Aus, obwohl es die Sicherung dahinter
        // ohnehin tut: Er ist der einzige Schreibweg ohne Zutun des Anwalts und
        // liefe in jedem Testhost im Halbstundentakt mit. Nach dem
        // ArbeitsplatzDienst registriert, damit der Arbeitsplatz-Eintrag steht,
        // bevor der erste Takt sichern kann (Hosted Services starten in
        // Registrierungsreihenfolge).
        if (eingeschaltet)
        {
            services.AddHostedService(sp => new SicherungsZeitgeber(
                sp.GetRequiredService<IAutomatischeSicherung>(),
                AppDataPaths.DatabaseFilePath,
                sp.GetRequiredService<ILogger<SicherungsZeitgeber>>()));
        }

        return services;
    }

    /// <summary>
    /// Liest einen Einstellungswert über einen eigenen Scope. Die Nutzer sind
    /// Singletons, der DbContext ist Scoped — ohne diesen Umweg hielte ein
    /// Singleton den ersten Kontext für immer fest.
    /// </summary>
    static string AusDenEinstellungen(
        IServiceProvider sp, Func<AutomationDbContext, string> lies)
    {
        using var scope = sp.GetRequiredService<IServiceScopeFactory>().CreateScope();
        return lies(scope.ServiceProvider.GetRequiredService<AutomationDbContext>());
    }
}
