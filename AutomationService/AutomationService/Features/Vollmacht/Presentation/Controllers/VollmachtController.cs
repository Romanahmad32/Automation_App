using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Vollmacht.Presentation.Controllers;

/// <summary>
/// Die Vollmacht zum Vorgang (§4.11): Stand der drei Vorlagen, Standarddrucker,
/// Seitenvorschau, Drucken und „In Word öffnen". Den Vermerk „gedruckt" setzt
/// das Frontend danach über <c>PUT api/Vorgaenge/vollmacht</c> — er gehört dem
/// Vorgang, nicht diesem Schnitt.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class VollmachtController(
    IVollmachtDienst dienst,
    VollmachtVorlagenOrdner vorlagen,
    IDruckerAuskunft druckerAuskunft) : ControllerBase
{
    [HttpGet("vorlagen")]
    [ProducesResponseType(typeof(VollmachtVorlagenDto), StatusCodes.Status200OK)]
    public ActionResult<VollmachtVorlagenDto> Vorlagen() =>
        Ok(new VollmachtVorlagenDto(
            vorlagen.Pfad,
            vorlagen.Stand().Select(VollmachtVorlageDto.From).ToList()));

    /// <summary>Der Standarddrucker, an den „Drucken" geht, und was Windows über ihn meldet.</summary>
    [HttpGet("drucker")]
    [ProducesResponseType(typeof(VollmachtDruckerDto), StatusCodes.Status200OK)]
    public ActionResult<VollmachtDruckerDto> Drucker() =>
        Ok(VollmachtDruckerDto.From(druckerAuskunft.Standarddrucker()));

    /// <summary>
    /// Die ausgefüllte Seite als PDF. Eine fehlende Vorlage oder eine Vorschau
    /// ohne Word sind kein HTTP-Fehler, sondern ein Status.
    /// </summary>
    [HttpPost("vorschau")]
    [ProducesResponseType(typeof(VollmachtVorschauDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VollmachtVorschauDto>> Vorschau([FromBody] VollmachtAuftragDto dto)
    {
        if (dto.ZuAuftrag() is not { } auftrag)
        {
            return UnbekannteArt(dto.Art);
        }

        return Ok(VollmachtVorschauDto.From(await dienst.VorschauAsync(auftrag)));
    }

    /// <summary>
    /// Füllt und druckt. Ein gescheiterter Druck ist kein HTTP-Fehler, sondern
    /// der Status <c>druckFehlgeschlagen</c> mit dem Pfad der Datei, die das
    /// Frontend dann öffnet.
    /// </summary>
    [HttpPost("drucken")]
    [ProducesResponseType(typeof(VollmachtErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VollmachtErgebnisDto>> Drucken(
        [FromBody] VollmachtAuftragDto dto,
        CancellationToken cancellationToken)
    {
        if (dto.ZuAuftrag() is not { } auftrag)
        {
            return UnbekannteArt(dto.Art);
        }

        return Ok(VollmachtErgebnisDto.From(await dienst.DruckeAsync(auftrag, cancellationToken)));
    }

    /// <summary>Füllt nur aus; die Datei bleibt zum Öffnen liegen.</summary>
    [HttpPost("oeffnen")]
    [ProducesResponseType(typeof(VollmachtErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public ActionResult<VollmachtErgebnisDto> Oeffnen([FromBody] VollmachtAuftragDto dto)
    {
        if (dto.ZuAuftrag() is not { } auftrag)
        {
            return UnbekannteArt(dto.Art);
        }

        return Ok(VollmachtErgebnisDto.From(dienst.FuelleAus(auftrag)));
    }

    private ObjectResult UnbekannteArt(string art) => Problem(
        detail: $"Unbekannte Vollmacht-Art „{art}“.",
        statusCode: StatusCodes.Status400BadRequest);
}
