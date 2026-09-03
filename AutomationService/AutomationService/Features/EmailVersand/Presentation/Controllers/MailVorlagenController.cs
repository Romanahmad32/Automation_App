using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// CRUD über die Mail-Textvorlagen (§4.7, §5.3) — der Bestand, aus dem der
/// Anwalt beim Verfassen wählt und den er in den Einstellungen pflegt.
/// Doppelte Namen ergeben 409, unbekannte Ids 404, ein fehlender Name 400 —
/// Betreff und Text dürfen leer bleiben (§1.3, §4.7).
///
/// Eigener Controller statt eines weiteren Zweigs im
/// <see cref="EmailVersandController"/>: Der versendet, dieser verwaltet — und
/// der andere ist schon lang genug.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MailVorlagenController(IMailVorlagenRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<MailVorlageDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MailVorlageDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var vorlagen = await repository.GetAllAsync(cancellationToken);
        return Ok(vorlagen.Select(MailVorlageDto.From).ToList());
    }

    [HttpPost]
    [ProducesResponseType(typeof(MailVorlageDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MailVorlageDto>> Create(
        [FromBody] SpeichereMailVorlageDto dto,
        CancellationToken cancellationToken)
    {
        var angelegt = await repository.CreateAsync(dto.ToEntity(), cancellationToken);
        return CreatedAtAction(nameof(GetAll), MailVorlageDto.From(angelegt));
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(MailVorlageDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MailVorlageDto>> Update(
        int id,
        [FromBody] MailVorlageDto dto,
        CancellationToken cancellationToken)
    {
        var geaendert = await repository.UpdateAsync(
            (dto with { Id = id }).ToEntity(), cancellationToken);
        return geaendert is null
            ? Problem(detail: $"Mail-Vorlage mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound)
            : Ok(MailVorlageDto.From(geaendert));
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var entfernt = await repository.DeleteAsync(id, cancellationToken);
        return entfernt ? NoContent() : Problem(detail: $"Mail-Vorlage mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound);
    }
}
