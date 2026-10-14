namespace AutomationService.Features.DevSimulation.Presentation.Dtos;

/// <summary>
/// Eingabe von <c>POST api/Simulation/aktualisierung</c> (#196): welcher Fall
/// beim nächsten Download der Update-Attrappe gilt.
/// </summary>
/// <param name="PruefsummeFalsch">
/// <c>true</c>: Die geladene Datei weicht in einem Byte ab; die Prüfung
/// verwirft sie, der Installer startet nicht. <c>false</c>: der gute Fall.
/// </param>
public sealed record SimulationAktualisierungDto(bool PruefsummeFalsch = false);
