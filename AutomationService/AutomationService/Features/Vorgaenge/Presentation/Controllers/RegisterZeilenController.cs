using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Vorgaenge.Presentation.Controllers;

/// <summary>
/// Die Zeilen der Registeransicht (§6.2) — laufende Vorgänge und übernommene
/// Historie in einer Folge, gebaut vom Backend.
///
/// Eigener Controller neben dem <see cref="RegisterSpiegelController"/> unter
/// derselben Route: Der schreibt eine Datei und braucht dafür Word und PDF,
/// dieser liest nur. Zusammengelegt zöge jeder Abruf der Ansicht die
/// Abhängigkeiten des Dateiexports mit sich.
/// </summary>
[ApiController]
[Route("api/Vorgaenge/register")]
public class RegisterZeilenController(IRegisterZeilenDienst zeilen) : ControllerBase
{
    /// <summary>
    /// Alle Registerzeilen; mit <paramref name="jahrgang"/> nur die eines
    /// Jahres. Laufende Vorgänge sind eingeschlossen — der Filter „nur
    /// abgeschlossene" gilt für die Spiegeldatei, nicht für den Bildschirm.
    /// </summary>
    [HttpGet("zeilen")]
    [ProducesResponseType(typeof(RegisterZeilenDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<RegisterZeilenDto>> Zeilen(
        [FromQuery] int? jahrgang,
        CancellationToken cancellationToken)
        => Ok(RegisterZeilenDto.From(await zeilen.LadeAsync(jahrgang, cancellationToken)));
}
