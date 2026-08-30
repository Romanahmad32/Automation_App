using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Settings.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Settings.Presentation.Controllers;

/// <summary>
/// Liest und speichert den einen Kanzlei-Einstellungssatz (§7.1) und zählt
/// die laufende Auftragsnummer hoch (§7.1). Ersetzt den früheren lokalen
/// JSON-Speicher des Frontends (kanzlei_settings.json). Dazu die
/// Standardpositionen der Schadensaufstellung (§4.4).
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SettingsController(
    IKanzleiSettingsRepository repository,
    IStandardSchadenspositionenRepository schadenspositionen) : ControllerBase
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

    [HttpGet("schadenspositionen")]
    [ProducesResponseType(typeof(IReadOnlyList<StandardSchadenspositionDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<StandardSchadenspositionDto>>> GetSchadenspositionen(
        CancellationToken cancellationToken)
    {
        var positionen = await schadenspositionen.GetAsync(cancellationToken);
        return Ok(positionen.Select(StandardSchadenspositionDto.From).ToList());
    }

    /// <summary>
    /// Ersetzt die komplette Liste; eine leere Liste setzt auf die fünf
    /// üblichen Positionen zurück (§4.4).
    /// </summary>
    [HttpPut("schadenspositionen")]
    [ProducesResponseType(typeof(IReadOnlyList<StandardSchadenspositionDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IReadOnlyList<StandardSchadenspositionDto>>> SaveSchadenspositionen(
        [FromBody] IReadOnlyList<StandardSchadenspositionDto> dtos,
        CancellationToken cancellationToken)
    {
        // Dieselbe Zusage wie an der Schadensposition selbst: kein negativer
        // Betrag — auch nicht als Vorbelegung.
        if (dtos.Any(dto => dto.Betrag < 0))
        {
            return BadRequest("Ein vorbelegter Betrag darf nicht negativ sein.");
        }

        var saved = await schadenspositionen.SaveAsync(
            dtos.Select(dto => dto.ToEntity()).ToList(),
            cancellationToken);
        return Ok(saved.Select(StandardSchadenspositionDto.From).ToList());
    }
}
