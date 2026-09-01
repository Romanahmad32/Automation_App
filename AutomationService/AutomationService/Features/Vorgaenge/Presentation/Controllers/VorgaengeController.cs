using System.Text.Json;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.Vorgaenge.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Vorgaenge.Presentation.Controllers;

/// <summary>
/// Liest und pflegt die Vorgänge (§3). Ersetzt den früheren lokalen
/// JSON-Speicher (zentralruf_vorgaenge.json). Upsert/Delete laufen pro Referenz,
/// damit auch bei tausenden Vorgängen jede Änderung nur eine Zeile schreibt.
/// Die Referenz enthält Schrägstriche/Leerzeichen und wird deshalb als
/// Query-Parameter übergeben, nicht im Pfad.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class VorgaengeController(
    IVorgangRepository repository,
    IVorgangAbschlussService abschlussService) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VorgangDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VorgangDto>>> GetAll(
        [FromQuery] string? status,
        [FromQuery] string? jahr,
        CancellationToken cancellationToken)
    {
        var vorgaenge = await repository.GetAllAsync(status, jahr, cancellationToken);
        return Ok(vorgaenge.Select(VorgangDto.From).ToList());
    }

    [HttpGet("einzeln")]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VorgangDto>> GetByReferenz(
        [FromQuery] string referenz,
        CancellationToken cancellationToken)
    {
        var vorgang = await repository.GetByReferenzAsync(referenz, cancellationToken);
        return vorgang is null ? NotFound() : Ok(VorgangDto.From(vorgang));
    }

    [HttpPut]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<VorgangDto>> Upsert(
        [FromBody] VorgangDto dto,
        CancellationToken cancellationToken)
    {
        var saved = await repository.UpsertAsync(dto.ToEntity(), cancellationToken);
        return Ok(VorgangDto.From(saved));
    }

    /// <summary>
    /// Hinterlegt den angefangenen Ausfüllstand des Word-Assistenten am Vorgang
    /// (§4.4). Eigener Weg statt eines Upsert des ganzen Vorgangs: Der Entwurf
    /// wird beim Tippen laufend geschrieben, und ein Upsert würde dabei jedes
    /// Mal alle übrigen Spalten aus der Sicht des Aufrufers überschreiben — auch
    /// eine inzwischen eingetroffene Zentralruf-Antwort.
    /// </summary>
    [HttpPut("entwurf")]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VorgangDto>> SetzeEntwurf(
        [FromQuery] string referenz,
        [FromBody] JsonElement entwurf,
        CancellationToken cancellationToken)
    {
        var vorgang = await repository.SetzeEntwurfAsync(
            referenz,
            entwurf.GetRawText(),
            cancellationToken);
        return vorgang is null ? NotFound() : Ok(VorgangDto.From(vorgang));
    }

    /// <summary>
    /// Verwirft den angefangenen Ausfüllstand — vom Anwalt ausgelöst („Verwerfen")
    /// oder nachdem aus ihm ein bestätigter Stand geworden ist. Die bestätigten
    /// Werte (<c>FeldWerte</c>) bleiben davon unberührt.
    /// </summary>
    [HttpDelete("entwurf")]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VorgangDto>> VerwirfEntwurf(
        [FromQuery] string referenz,
        CancellationToken cancellationToken)
    {
        var vorgang = await repository.SetzeEntwurfAsync(referenz, null, cancellationToken);
        return vorgang is null ? NotFound() : Ok(VorgangDto.From(vorgang));
    }

    /// <summary>
    /// Schließt den Vorgang ab (§4.8): Status „versendet" und Hochzählen der
    /// laufenden Auftragsnummer (§7.1) in einer Transaktion. Idempotent —
    /// ein bereits abgeschlossener Vorgang zählt nicht erneut hoch.
    /// </summary>
    [HttpPost("abschliessen")]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VorgangDto>> Abschliessen(
        [FromQuery] string referenz,
        CancellationToken cancellationToken)
    {
        var vorgang = await abschlussService.AbschliessenAsync(referenz, cancellationToken);
        return vorgang is null ? NotFound() : Ok(VorgangDto.From(vorgang));
    }

    /// <summary>
    /// Benennt einen Vorgang um (Referenz korrigieren, z. B. Tippfehler im
    /// Kennzeichen). Die Referenz ist der fachliche Schlüssel — ein einfaches
    /// Upsert unter der neuen Referenz würde ein Duplikat anlegen; deshalb
    /// dieser eigene, konfliktgeprüfte Weg. 409, wenn die Zielreferenz schon
    /// einem anderen Vorgang gehört.
    /// </summary>
    [HttpPost("referenz")]
    [ProducesResponseType(typeof(VorgangDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<VorgangDto>> AendereReferenz(
        [FromQuery] string von,
        [FromQuery] string nach,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(nach))
        {
            return Problem(
                detail: "Die neue Referenz darf nicht leer sein.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var ergebnis = await repository.RenameReferenzAsync(von, nach, cancellationToken);
        return ergebnis.Status switch
        {
            ReferenzAenderungStatus.NichtGefunden => NotFound(),
            ReferenzAenderungStatus.Vergeben => Conflict(),
            _ => Ok(VorgangDto.From(ergebnis.Vorgang!)),
        };
    }

    [HttpDelete]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(
        [FromQuery] string referenz,
        CancellationToken cancellationToken)
    {
        var removed = await repository.DeleteAsync(referenz, cancellationToken);
        return removed ? NoContent() : NotFound();
    }
}
