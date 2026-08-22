using System.Text.Json;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// CRUD über das Mandantenregister (§5.1). Ersetzt den früheren lokalen
/// JSON-Speicher des Frontends (mandanten.json). Namens-Dubletten ergeben 409,
/// unbekannte IDs 404.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MandantenController(IMandantenRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<MandantDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MandantDto>>> GetAll(CancellationToken cancellationToken)
    {
        var mandanten = await repository.GetAllAsync(cancellationToken);
        return Ok(mandanten.Select(MandantDto.From).ToList());
    }

    [HttpPost]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MandantDto>> Create(
        [FromBody] CreateMandantDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var created = await repository.CreateAsync(ToEntity(dto), cancellationToken);
            return CreatedAtAction(nameof(GetAll), MandantDto.From(created));
        }
        catch (MandantNameConflictException exception)
        {
            return Conflict(exception.Message);
        }
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MandantDto>> Update(
        int id,
        [FromBody] MandantDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var updated = await repository.UpdateAsync(ToEntity(dto with { Id = id }), cancellationToken);
            return updated is null
                ? NotFound($"Mandant mit ID {id} nicht gefunden")
                : Ok(MandantDto.From(updated));
        }
        catch (MandantNameConflictException exception)
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
        return removed ? NoContent() : NotFound($"Mandant mit ID {id} nicht gefunden");
    }

    static MandantEntity ToEntity(CreateMandantDto dto) => new()
    {
        Anrede = dto.Anrede,
        Vorname = dto.Vorname,
        Nachname = dto.Nachname,
        StrasseHausnummer = dto.StrasseHausnummer,
        Postleitzahl = dto.Postleitzahl,
        Ort = dto.Ort,
        EmailAdresse = dto.EmailAdresse,
        Telefonnummer = dto.Telefonnummer,
        Notiz = dto.Notiz,
        AktenOrdnernamenJson = JsonSerializer.Serialize(dto.AktenOrdnernamen),
        KennzeichenJson = JsonSerializer.Serialize(dto.Kennzeichen),
    };

    static MandantEntity ToEntity(MandantDto dto) => new()
    {
        Id = dto.Id,
        Anrede = dto.Anrede,
        Vorname = dto.Vorname,
        Nachname = dto.Nachname,
        StrasseHausnummer = dto.StrasseHausnummer,
        Postleitzahl = dto.Postleitzahl,
        Ort = dto.Ort,
        EmailAdresse = dto.EmailAdresse,
        Telefonnummer = dto.Telefonnummer,
        Notiz = dto.Notiz,
        AktenOrdnernamenJson = JsonSerializer.Serialize(dto.AktenOrdnernamen),
        KennzeichenJson = JsonSerializer.Serialize(dto.Kennzeichen),
    };
}
