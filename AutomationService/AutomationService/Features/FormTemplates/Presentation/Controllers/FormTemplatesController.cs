using AutomationService.Core.Persistence;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.FormTemplates.Domain.Services;
using AutomationService.Features.FormTemplates.Presentation.Dtos;
using AutomationService.Features.Settings.Domain.Services;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.FormTemplates.Presentation.Controllers;

/// <summary>
/// CRUD über die benutzerdefinierten Formularvorlagen. Ersetzt den früheren
/// lokalen JSON-Speicher (form_templates.json). Doppelte Namen ergeben 409,
/// unbekannte IDs 404.
///
/// Hier liegt die Umrechnungsgrenze der Word-Pfade (#33): hinaus gehen sie
/// aufgelöst (absolut), hinein kommende werden relativ zum eingestellten
/// Vorlagenordner gespeichert, wenn die Datei darin liegt. Das fängt auch den
/// Rückschreibweg des Wizards ab, der aufgelöste Pfade per PUT zurückschickt.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class FormTemplatesController(
    IFormTemplateRepository repository,
    AutomationDbContext db) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<FormTemplateDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<FormTemplateDto>>> GetAll(CancellationToken cancellationToken)
    {
        var ordner = VorlagenOrdnerVorgabe.Ermittle(db);
        var templates = await repository.GetAllAsync(cancellationToken);
        return Ok(templates.Select(t => FormTemplateDto.From(t, ordner)).ToList());
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
            var ordner = VorlagenOrdnerVorgabe.Ermittle(db);
            var created = await repository.CreateAsync(
                RelativiertePfade(dto.ToEntity(), ordner), cancellationToken);
            return CreatedAtAction(nameof(GetAll), FormTemplateDto.From(created, ordner));
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
            var ordner = VorlagenOrdnerVorgabe.Ermittle(db);
            var updated = await repository.UpdateAsync(
                RelativiertePfade((dto with { Id = id }).ToEntity(), ordner), cancellationToken);
            return updated is null
                ? NotFound($"Vorlage mit ID {id} nicht gefunden")
                : Ok(FormTemplateDto.From(updated, ordner));
        }
        catch (FormTemplateNameConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    static FormTemplateEntity RelativiertePfade(FormTemplateEntity entity, string ordner)
    {
        entity.WordFilePathOhneAuflistung = VorlagenPfad.MacheRelativ(ordner, entity.WordFilePathOhneAuflistung);
        entity.WordFilePathMitAuflistung = VorlagenPfad.MacheRelativ(ordner, entity.WordFilePathMitAuflistung);
        return entity;
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
