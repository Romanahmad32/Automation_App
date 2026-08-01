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
}
