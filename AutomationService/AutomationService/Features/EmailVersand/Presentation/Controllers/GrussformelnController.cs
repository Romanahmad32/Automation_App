using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// CRUD über die persönlichen Grußformeln (§4.7, §7.1) — die Liste, aus der
/// der Anwalt beim Verfassen wählt und die er in den Einstellungen pflegt.
/// Doppelte Grüße ergeben 409, unbekannte Ids 404, ein fehlender Text 400.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class GrussformelnController(IGrussformelnRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<GrussformelDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<GrussformelDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var grussformeln = await repository.GetAllAsync(cancellationToken);
        return Ok(grussformeln.Select(GrussformelDto.From).ToList());
    }

    [HttpPost]
    [ProducesResponseType(typeof(GrussformelDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<GrussformelDto>> Create(
        [FromBody] SpeichereGrussformelDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var angelegt = await repository.CreateAsync(dto.ToEntity(), cancellationToken);
            return CreatedAtAction(nameof(GetAll), GrussformelDto.From(angelegt));
        }
        catch (GrussformelUngueltigException exception)
        {
            return BadRequest(exception.Message);
        }
        catch (GrussformelTextConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(GrussformelDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<GrussformelDto>> Update(
        int id,
        [FromBody] GrussformelDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var geaendert = await repository.UpdateAsync(
                (dto with { Id = id }).ToEntity(), cancellationToken);
            return geaendert is null
                ? NotFound($"Grussformel mit ID {id} nicht gefunden")
                : Ok(GrussformelDto.From(geaendert));
        }
        catch (GrussformelUngueltigException exception)
        {
            return BadRequest(exception.Message);
        }
        catch (GrussformelTextConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var entfernt = await repository.DeleteAsync(id, cancellationToken);
        return entfernt ? NoContent() : NotFound($"Grussformel mit ID {id} nicht gefunden");
    }
}
