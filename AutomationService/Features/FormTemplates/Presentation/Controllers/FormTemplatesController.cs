using AutomationService.Features.FormTemplates.Domain.Services;
using AutomationService.Features.FormTemplates.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.FormTemplates.Presentation.Controllers;

/// <summary>
/// CRUD über die benutzerdefinierten Formularvorlagen. Ersetzt den früheren
/// lokalen JSON-Speicher (form_templates.json). Doppelte Namen ergeben 409,
/// unbekannte IDs 404.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class FormTemplatesController(IFormTemplateRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<FormTemplateDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FormTemplateDto>>> GetAll(CancellationToken cancellationToken)
    {
        var templates = await repository.GetAllAsync(cancellationToken);
        return Ok(templates.Select(FormTemplateDto.From).ToList());
    }

    [HttpPost]
    [ProducesResponseType(typeof(FormTemplateDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<FormTemplateDto>> Create(
        [FromBody] CreateFormTemplateDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var created = await repository.CreateAsync(dto.ToEntity(), cancellationToken);
            return CreatedAtAction(nameof(GetAll), FormTemplateDto.From(created));
        }
        catch (FormTemplateNameConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(FormTemplateDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<FormTemplateDto>> Update(
        int id,
        [FromBody] FormTemplateDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var updated = await repository.UpdateAsync((dto with { Id = id }).ToEntity(), cancellationToken);
            return updated is null
                ? NotFound($"Vorlage mit ID {id} nicht gefunden")
                : Ok(FormTemplateDto.From(updated));
        }
        catch (FormTemplateNameConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var removed = await repository.DeleteAsync(id, cancellationToken);
        return removed ? NoContent() : NotFound($"Vorlage mit ID {id} nicht gefunden");
    }
}
