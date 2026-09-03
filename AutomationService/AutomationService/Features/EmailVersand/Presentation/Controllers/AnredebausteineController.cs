using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// CRUD über die Anredeanfänge (§4.7, §7.1) — die Liste, aus der der Anwalt
/// beim Verfassen wählt und die er in den Einstellungen pflegt. Doppelte
/// Anfänge ergeben 409, unbekannte Ids 404, fehlende Formen 400.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AnredebausteineController(IAnredeBausteineRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<AnredeBausteinDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AnredeBausteinDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var bausteine = await repository.GetAllAsync(cancellationToken);
        return Ok(bausteine.Select(AnredeBausteinDto.From).ToList());
    }

    [HttpPost]
    [ProducesResponseType(typeof(AnredeBausteinDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AnredeBausteinDto>> Create(
        [FromBody] SpeichereAnredeBausteinDto dto,
        CancellationToken cancellationToken)
    {
        var angelegt = await repository.CreateAsync(dto.ToEntity(), cancellationToken);
        return CreatedAtAction(nameof(GetAll), AnredeBausteinDto.From(angelegt));
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(AnredeBausteinDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AnredeBausteinDto>> Update(
        int id,
        [FromBody] AnredeBausteinDto dto,
        CancellationToken cancellationToken)
    {
        var geaendert = await repository.UpdateAsync(
            (dto with { Id = id }).ToEntity(), cancellationToken);
        return geaendert is null
            ? Problem(detail: $"Anredebaustein mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound)
            : Ok(AnredeBausteinDto.From(geaendert));
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var entfernt = await repository.DeleteAsync(id, cancellationToken);
        return entfernt ? NoContent() : Problem(detail: $"Anredebaustein mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound);
    }
}
