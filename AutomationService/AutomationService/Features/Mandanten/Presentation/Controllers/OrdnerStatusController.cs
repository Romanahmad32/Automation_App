using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// Vermerke zu Akten-Ordnern ohne Mandantenbezug (§6.1). Zwei Routen genügen:
/// lesen und setzen — Zurücknehmen ist dasselbe Setzen mit <c>status: null</c>,
/// und beide arbeiten auf einer Liste, damit die Massenaktion über hunderte
/// Ordner ein Aufruf bleibt statt hunderter.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class OrdnerStatusController(IOrdnerStatusRegister register) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<OrdnerStatusDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<OrdnerStatusDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var eintraege = await register.GetAllAsync(cancellationToken);
        return Ok(eintraege.Select(OrdnerStatusDto.From).ToList());
    }

    /// <summary>
    /// Antwortet mit dem vollständigen Stand danach — die Oberfläche übernimmt
    /// ihn, statt nach einer Massenaktion neu zu laden.
    /// </summary>
    [HttpPut]
    [ProducesResponseType(typeof(IReadOnlyList<OrdnerStatusDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IReadOnlyList<OrdnerStatusDto>>> Setze(
        [FromBody] SetzeOrdnerStatusDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var stand = await register.SetzeAsync(dto.Ordnernamen, dto.Status, cancellationToken);
            return Ok(stand.Select(OrdnerStatusDto.From).ToList());
        }
        catch (ArgumentException exception)
        {
            return BadRequest(exception.Message);
        }
    }
}
