using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.RegisterHistorie.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.RegisterHistorie.Presentation.Controllers;

/// <summary>
/// Der Stand der übernommenen Registerhistorie und die Berichtigung einzelner
/// Zeilen (§6.2).
///
/// Getrennt vom Import, weil beides verschiedene Dinge tut: Der Import liest
/// eine Datei, dieser Weg pflegt den Bestand. Zusammengelegt teilten sie sich
/// Abhängigkeiten, die keiner von beiden braucht.
///
/// Gelesen wird der Bestand hier bewusst <b>nicht</b> — die Zeilen holt die
/// Ansicht über <c>GET api/Vorgaenge/register/zeilen</c>, damit Historie und
/// laufende Vorgänge aus einer Quelle kommen und Bildschirm und Word/PDF-Spiegel
/// per Konstruktion dasselbe sagen.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class RegisterHistorieController(IRegisterHistorie historie) : ControllerBase
{
    [HttpGet("stand")]
    [ProducesResponseType(typeof(RegisterHistorieStandDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<RegisterHistorieStandDto>> Stand(CancellationToken cancellationToken)
        => Ok(RegisterHistorieStandDto.From(await historie.StandAsync(cancellationToken)));

    /// <summary>
    /// Eine einzelne Zeile — was der Bearbeiten-Dialog beim Öffnen holt. Er
    /// braucht mehr als die Registeransicht zeigt: den Freitext als Beleg, die
    /// Befunde und die Hinweise des Erzeugers.
    /// </summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(RegisterHistorieZeileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RegisterHistorieZeileDto>> Zeile(
        int id,
        CancellationToken cancellationToken)
    {
        var zeile = await historie.GetAsync(id, cancellationToken);
        return zeile is null ? NotFound() : Ok(RegisterHistorieZeileDto.From(zeile));
    }

    /// <summary>
    /// Berichtigt eine historische Zeile. Die Bestätigung davor holt die
    /// Oberfläche ein: Was hier ankommt, ist bereits die Entscheidung des
    /// Anwalts, und der Dienst führt sie aus, statt sie ein zweites Mal zu
    /// hinterfragen.
    /// </summary>
    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(RegisterHistorieZeileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RegisterHistorieZeileDto>> Aendere(
        int id,
        [FromBody] RegisterHistorieAenderungDto aenderung,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(aenderung);

        var zeile = await historie.AendereAsync(id, aenderung.ZuDomaene(), cancellationToken);
        return zeile is null ? NotFound() : Ok(RegisterHistorieZeileDto.From(zeile));
    }

    /// <summary>
    /// Löscht eine historische Zeile für sich (§6.3). Nur für Zeilen ohne
    /// Vorgang gedacht — eine Spiegelzeile eines Vorgangs lässt sich nur
    /// zusammen mit ihm löschen (<c>DELETE api/Vorgaenge</c> mit
    /// <c>registerzeileBehalten=false</c>); dafür braucht es hier keinen
    /// eigenen Weg, weil die Zeile sonst beim nächsten Schreiben wiederkäme.
    /// </summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Loesche(int id, CancellationToken cancellationToken)
    {
        var geloescht = await historie.LoescheAsync(id, cancellationToken);
        return geloescht ? NoContent() : NotFound();
    }
}
