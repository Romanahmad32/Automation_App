using System.Globalization;
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

    /// <summary>
    /// Der Nummernstand eines Jahrgangs (§6.3): der Vorschlag für die nächste
    /// laufende Nummer und die im Jahrgang schon belegten. Ohne
    /// <paramref name="jahrgang"/> gilt das laufende Kalenderjahr — der
    /// Jahrgang, in dem ein neuer Vorgang heute landet.
    /// </summary>
    [HttpGet("nummern")]
    [ProducesResponseType(typeof(RegisterNummernDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<RegisterNummernDto>> Nummern(
        [FromQuery] int? jahrgang,
        CancellationToken cancellationToken)
    {
        var jahr = jahrgang ?? DateTime.Now.Year;
        var alleZeilen = await zeilen.LadeAsync(jahr, cancellationToken);
        var stand = RegisterNummern.Stand(alleZeilen, jahr.ToString(CultureInfo.InvariantCulture));
        return Ok(RegisterNummernDto.From(stand));
    }
}
