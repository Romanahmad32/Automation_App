using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// Was zu einem Vorgang schon hinausgegangen ist (REQUIREMENTS.md §4.7):
/// wann, an wen, mit welchen Anhängen.
///
/// Für eine Kanzlei ist das der Nachweis, dass das Anspruchsschreiben raus
/// ist. Bis hierher hielt die App den Versandstand nur für die Dauer eines
/// Dialogs; danach war die Frage „wann ging das hinaus?" nur noch im Postfach
/// zu beantworten.
///
/// Eigener Controller neben <see cref="EmailVersandController"/> und mit
/// ausdrücklicher Route, damit die Pfade dieselben bleiben: Verfassen und
/// Senden ist das eine, das Nachschlagen im Protokoll das andere — und der
/// Versand-Controller war voll.
/// </summary>
[ApiController]
[Route("api/EmailVersand/protokoll")]
public class VersandProtokollController(VersandProtokoll protokoll) : ControllerBase
{
    /// <summary>
    /// Alle Versände zu diesem Vorgang, der jüngste zuerst. Ohne Referenz eine
    /// leere Liste — kein Fehler: Ein Anschreiben ohne Vorgang hat keine Akte,
    /// an der es hinge.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VersandEintragDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VersandEintragDto>>> GetZuVorgang(
        [FromQuery] string? referenz,
        CancellationToken cancellationToken)
    {
        var eintraege = await protokoll.ZuAsync(referenz ?? string.Empty, cancellationToken);
        return Ok(eintraege.Select(VersandEintragDto.From).ToList());
    }

    /// <summary>
    /// Je Vorgang der jüngste Versand — für die Liste in der
    /// Vorgangsverwaltung. Ein Aufruf statt einer Nachfrage je Zeile.
    /// </summary>
    [HttpGet("letzte")]
    [ProducesResponseType(typeof(IReadOnlyList<VersandEintragDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VersandEintragDto>>> GetLetzte(
        CancellationToken cancellationToken)
    {
        var eintraege = await protokoll.LetzteJeVorgangAsync(cancellationToken);
        return Ok(eintraege.Select(VersandEintragDto.From).ToList());
    }
}
