using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.DevSimulation.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.DevSimulation.Presentation.Controllers;

/// <summary>
/// Steuert die Update-Attrappe des E2E-Testmodus (#196). Ein eigener Controller
/// unter derselben Route wie <see cref="SimulationController"/>, damit dessen
/// Abhängigkeiten nicht für jeden Aufruf wachsen.
/// </summary>
[ApiController]
[Route("api/Simulation")]
public class SimulationAktualisierungController(
    IOptions<SimulationOptions> options,
    IAktualisierungsQuelle quelle,
    IAktualisierungsDienst dienst) : ControllerBase
{
    /// <summary>
    /// Stellt den Fall der Attrappe ein und setzt den Update-Stand zurück, als
    /// wäre der Dienst eben gestartet: laufenden Download abbrechen,
    /// heruntergeladene Setup-Dateien löschen. Ohne das Zurücksetzen bliebe ein
    /// Durchlauf nach einem anderen auf <c>bereit</c> stehen, denn die Suite
    /// fährt alle Durchläufe gegen denselben Dienst.
    ///
    /// 404 ohne <c>Simulation:Enabled</c> (wie jeder Simulations-Endpunkt), 409
    /// ohne Testmodus: Dann ist die Quelle die echte, und es gäbe nichts
    /// umzuschalten.
    /// </summary>
    [HttpPost("aktualisierung")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> StelleEin([FromBody] SimulationAktualisierungDto dto)
    {
        if (!options.Value.Enabled) return NotFound();
        if (quelle is not TestmodusAktualisierungsQuelle attrappe)
        {
            return Problem(
                detail: "Die Update-Attrappe gibt es nur im Testmodus (Simulation:Testmodus).",
                statusCode: StatusCodes.Status409Conflict);
        }

        attrappe.PruefsummeFalsch = dto.PruefsummeFalsch;
        await dienst.SetzeZurueckAsync();
        return NoContent();
    }
}
