using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Vorgaenge.Presentation.Controllers;

/// <summary>
/// Der Register-Spiegel als Word- und PDF-Datei im eingestellten Ablageordner
/// (§6.2, #40).
///
/// Eigener Controller statt zweier weiterer Aktionen am
/// <see cref="VorgaengeController"/>: Der pflegt Vorgänge, dieser schreibt eine
/// Datei — zwei verschiedene Dinge, die sich sonst dieselben Abhängigkeiten
/// teilen müssten.
///
/// Beide Wege antworten immer mit 200 und einem Ergebnis. Ein gesperrtes Ziel
/// ist kein Serverfehler, sondern eine Lage, die die Oberfläche in einem Satz
/// erklären und der Anwender sofort beheben kann.
/// </summary>
[ApiController]
[Route("api/Vorgaenge/register")]
public class RegisterSpiegelController(IRegisterSpiegelService spiegel) : ControllerBase
{
    /// <summary>
    /// Schreibt den Spiegel neu — der Weg für den Knopf auf der Registerseite.
    /// </summary>
    /// <param name="erzwingen">
    /// Auch schreiben, wenn sich nichts geändert hat. Vorbelegt mit
    /// <c>true</c>, weil hinter dem Knopf in aller Regel „die Datei ist weg
    /// oder sieht falsch aus" steht — und ein „nichts zu tun" darauf die
    /// unbrauchbarste aller Antworten wäre. Der automatische Lauf nach dem
    /// Vorgangsabschluss erzwingt nicht.
    /// </param>
    /// <param name="cancellationToken">Bricht die PDF-Erzeugung ab.</param>
    [HttpPost("export")]
    [ProducesResponseType(typeof(RegisterSpiegelDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<RegisterSpiegelDto>> Export(
        [FromQuery] bool erzwingen = true,
        CancellationToken cancellationToken = default)
    {
        var ergebnis = await spiegel.SchreibeAsync(erzwingen, cancellationToken);
        return Ok(RegisterSpiegelDto.From(ergebnis));
    }

    /// <summary>
    /// Was der letzte Lauf hinterlassen hat, ohne selbst zu schreiben — damit
    /// die Registerseite beim Öffnen sagen kann, ob der Spiegel aktuell ist und
    /// ob eine Konfliktkopie neben ihm liegt.
    /// </summary>
    [HttpGet("stand")]
    [ProducesResponseType(typeof(RegisterSpiegelDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<RegisterSpiegelDto>> Stand(CancellationToken cancellationToken)
    {
        var ergebnis = await spiegel.StandAsync(cancellationToken);
        return Ok(RegisterSpiegelDto.From(ergebnis));
    }
}
