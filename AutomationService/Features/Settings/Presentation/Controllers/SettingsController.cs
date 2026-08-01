using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Settings.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Settings.Presentation.Controllers;

/// <summary>
/// Liest und speichert den einen Kanzlei-Einstellungssatz (Req. 3.1) und zählt
/// die laufende Auftragsnummer hoch (Req. 3.2). Ersetzt den früheren lokalen
/// JSON-Speicher des Frontends (kanzlei_settings.json).
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SettingsController(IKanzleiSettingsRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(KanzleiSettingsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<KanzleiSettingsDto>> Get(CancellationToken cancellationToken)
    {
        var settings = await repository.GetAsync(cancellationToken);
        return Ok(KanzleiSettingsDto.From(settings));
    }

    [HttpPut]
    [ProducesResponseType(typeof(KanzleiSettingsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<KanzleiSettingsDto>> Save(
        [FromBody] KanzleiSettingsDto dto,
        CancellationToken cancellationToken)
    {
        var saved = await repository.SaveAsync(dto.ToEntity(), cancellationToken);
        return Ok(KanzleiSettingsDto.From(saved));
    }

    /// <summary>Erhöht die laufende Auftragsnummer um eins (nach Vorgangsabschluss).</summary>
    [HttpPost("auftragsnummer/erhoehe")]
    [ProducesResponseType(typeof(KanzleiSettingsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<KanzleiSettingsDto>> ErhoeheAuftragsnummer(
        CancellationToken cancellationToken)
    {
        var saved = await repository.ErhoeheAuftragsnummerAsync(cancellationToken);
        return Ok(KanzleiSettingsDto.From(saved));
    }
}
