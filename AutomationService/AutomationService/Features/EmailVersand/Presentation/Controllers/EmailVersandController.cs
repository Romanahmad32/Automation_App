using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// Versendet die fertig verfasste Mail zum Vorgang (REQUIREMENTS.md §4.7).
/// Verfasst wird in der Oberfläche; dieser Endpunkt bekommt sie fertig und
/// übergibt sie dem Postausgangsserver der Kanzlei.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class EmailVersandController(IEmailVersender versender, IEntwurfOeffner oeffner)
    : ControllerBase
{
    /// <summary>
    /// Meldet, ob gesendet werden kann und von welcher Adresse aus. Die
    /// Oberfläche fragt das ab, bevor der Anwalt zu tippen beginnt.
    /// </summary>
    [HttpGet("bereitschaft")]
    [ProducesResponseType(typeof(EmailVersandBereitschaftDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<EmailVersandBereitschaftDto>> GetBereitschaft(
        CancellationToken cancellationToken)
    {
        var bereitschaft = await versender.PruefeBereitschaftAsync(cancellationToken);
        return Ok(EmailVersandBereitschaftDto.From(bereitschaft));
    }

    /// <summary>
    /// Meldet die Signaturen, die im Outlook dieses Rechners eingerichtet
    /// sind (§4.7). Zum einmaligen Übernehmen in die Einstellungen — danach
    /// hängt der Versand nicht mehr an Outlook. Eine leere Liste heißt: hier
    /// ist keine eingerichtet, und das ist kein Fehler.
    /// </summary>
    [HttpGet("signaturen")]
    [ProducesResponseType(typeof(IReadOnlyList<OutlookSignaturDto>), StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<OutlookSignaturDto>> GetSignaturen() =>
        Ok(OutlookSignaturen.Lies().Select(OutlookSignaturDto.From).ToList());

    /// <summary>
    /// Sendet die Mail. Entweder ganz oder gar nicht: Bei einem Fehler ist
    /// nichts hinausgegangen, und der Grund steht im Klartext in den
    /// ProblemDetails.
    /// </summary>
    [HttpPost("senden")]
    [ProducesResponseType(typeof(EmailVersandErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<EmailVersandErgebnisDto>> Senden(
        [FromBody] EmailVersandDto anfrage,
        CancellationToken cancellationToken)
    {
        try
        {
            var ergebnis = await versender.SendeAsync(anfrage.ToDomain(), cancellationToken);
            return Ok(EmailVersandErgebnisDto.From(ergebnis));
        }
        catch (EmailVersandException exception)
        {
            return Problem(
                title: "Die E-Mail wurde nicht versendet",
                detail: exception.Message,
                statusCode: StatusFuer(exception.Grund));
        }
    }

    /// <summary>
    /// Öffnet die Mail als Entwurf im Mailprogramm, statt sie zu senden
    /// (§4.7). Gesendet wird dort von Hand — die App erfährt davon nichts
    /// mehr, deshalb bleibt das Häkchen beim Abschluss manuell (§4.8).
    /// </summary>
    [HttpPost("entwurf")]
    [ProducesResponseType(typeof(EntwurfErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<EntwurfErgebnisDto>> Entwurf(
        [FromBody] EmailVersandDto anfrage,
        CancellationToken cancellationToken)
    {
        try
        {
            var ergebnis = await oeffner.OeffneAsync(anfrage.ToDomain(), cancellationToken);
            return Ok(EntwurfErgebnisDto.From(ergebnis));
        }
        catch (EmailVersandException exception)
        {
            return Problem(
                title: "Der Entwurf wurde nicht geöffnet",
                detail: exception.Message,
                statusCode: StatusFuer(exception.Grund));
        }
    }

    /// <summary>
    /// Was der Anwalt selbst beheben kann, ist eine 400 — was der Server
    /// verweigert hat, eine 502. Die Unterscheidung entscheidet in der
    /// Oberfläche darüber, ob ein erneuter Versuch überhaupt Sinn hat.
    /// </summary>
    private static int StatusFuer(EmailVersandFehler grund) => grund switch
    {
        EmailVersandFehler.Anmeldung
            or EmailVersandFehler.Server
            or EmailVersandFehler.Entwurf => StatusCodes.Status502BadGateway,
        _ => StatusCodes.Status400BadRequest,
    };
}
