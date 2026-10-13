namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Schalter für die Entwickler-Simulation (Abschnitt "Simulation" in
/// appsettings). Standard ist <c>false</c>; nur appsettings.Development.json
/// schaltet sie ein — im ausgelieferten Produkt bleiben die
/// Simulations-Endpunkte damit unsichtbar (404).
/// </summary>
public sealed class SimulationOptions
{
    public const string SectionName = "Simulation";

    public bool Enabled { get; set; }

    /// <summary>
    /// E2E-Testmodus (#168, <c>Simulation:Testmodus</c>): Zentralruf-Anfrage,
    /// SMTP-Versand, Gesendet-Ablage, Outlook, Entwurfsdatei und Druck laufen
    /// gegen Attrappen, die nichts nach außen geben und ihre Spuren unter
    /// <c>&lt;Datenordner&gt;\Testmodus\</c> hinterlassen (<see cref="TestmodusOrdner"/>).
    ///
    /// Gilt nur zusammen mit umgelenktem Datenordner und außerhalb von
    /// Production; sonst bricht der Start ab. Gesetzt in appsettings.E2E.json,
    /// die nicht ins Paket geht.
    /// </summary>
    public bool Testmodus { get; set; }
}
