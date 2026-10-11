using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Vollmacht.Presentation.Controllers;

/// <summary>
/// Die Vollmacht zum Vorgang (§4.11): Stand der drei Vorlagen, Standarddrucker,
/// Seitenvorschau, Drucken, „In Word öffnen" und das Aufräumen der
/// Arbeitsdateien beim Schließen des Dialogs. Den Vermerk „gedruckt" setzt
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
    /// <summary>
    /// Der Ordner und der Stand seiner drei Vorlagen samt ihren Platzhaltern
    /// (#171). Eine unlesbare Vorlage ist kein HTTP-Fehler: Ihre Platzhalter
    /// sind dann <c>null</c>.
    /// </summary>
    [HttpGet("vorlagen")]
    [ProducesResponseType(typeof(VollmachtVorlagenDto), StatusCodes.Status200OK)]
    public ActionResult<VollmachtVorlagenDto> Vorlagen() =>
        Ok(new VollmachtVorlagenDto(
            vorlagen.Pfad,
            dienst.Vorlagen().Select(VollmachtVorlageDto.From).ToList()));

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

    /// <summary>
    /// Löscht die Vollmachtdateien im Arbeitsordner des Vorgangs. Das Frontend
    /// ruft das beim Schließen des Dialogs, wenn darin eine Word-Fassung
    /// entstanden ist (#174) — die Vollmacht wird nicht digital aufbewahrt
    /// (§8). Nicht <c>POST api/WordAutomation/arbeitsordner/aufraeumen</c>: Der
    /// nähme ein angefangenes Anspruchsschreiben daneben mit. Eine noch in Word
    /// geöffnete Datei bleibt still liegen, deshalb immer 204.
    /// </summary>
    [HttpPost("aufraeumen")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public IActionResult Aufraeumen([FromBody] VollmachtAufraeumenDto dto)
    {
        dienst.RaeumeAuf(dto.Referenz);
        return NoContent();
    }

    private ObjectResult UnbekannteArt(string art) => Problem(
        detail: $"Unbekannte Vollmacht-Art „{art}“.",
        statusCode: StatusCodes.Status400BadRequest);
}
