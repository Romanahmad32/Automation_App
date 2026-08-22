using AutomationService.Features.Versicherer.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ZentralrufController(
    IZentralrufAutomationService zentralrufAutomationService,
    IZentralrufReplyParser zentralrufReplyParser,
    IVersichererWissen versichererWissen,
    ILogger<ZentralrufController> logger) : ControllerBase
{
    /// <summary>
    /// Felder, die für die Vorlagenausfüllung gebraucht werden; fehlen sie in
    /// der geparsten Antwort, werden sie als "missing" zurückgemeldet (§4.3).
    /// </summary>
    private static readonly (string Name, Func<Domain.Services.ZentralrufReplyData, string?> Value)[] RelevantFields =
    [
        ("Referenz", data => data.Referenz),
        ("Kennzeichen", data => data.Kennzeichen),
        ("UnfallDatum", data => data.UnfallDatum),
        ("VersichererName", data => data.VersichererName),
        ("VersichererStrasse", data => data.VersichererStrasse),
        ("VersichererPlz", data => data.VersichererPlz),
        ("VersichererOrt", data => data.VersichererOrt),
        ("VersichererEmail", data => data.VersichererEmail),
        ("VersicherungsscheinNr", data => data.VersicherungsscheinNr),
    ];

    [HttpPost("antwort/parse")]
    [ProducesResponseType(typeof(ZentralrufReplyParseResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ZentralrufReplyParseResponseDto), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ZentralrufReplyParseResponseDto>> ParseReply(
        [FromBody] ZentralrufReplyParseRequestDto request,
        CancellationToken cancellationToken)
    {
        string emailText;
        try
        {
            emailText = ZentralrufReplyEmailExtractor.ExtractText(request.EmailText, request.EmailFileBase64);
        }
        catch (FormatException)
        {
            return BadRequest(new ZentralrufReplyParseResponseDto(
                false, null, [], [], "invalid_eml", "Die E-Mail-Datei konnte nicht gelesen werden."));
        }

        if (string.IsNullOrWhiteSpace(emailText))
        {
            return BadRequest(new ZentralrufReplyParseResponseDto(
                false, null, [], [], "validation_failed", "Der E-Mail-Text darf nicht leer sein."));
        }

        var data = zentralrufReplyParser.Parse(emailText);
        var missingFields = RelevantFields
            .Where(field => string.IsNullOrWhiteSpace(field.Value(data)))
            .Select(field => field.Name)
            .ToList();

        // Eine Negativ-Antwort oder Zwischennachricht ist eine echte Zentralruf-
        // Mail ohne Versichererdaten — die darf nicht als "keine Zentralruf-
        // Antwort" abgewiesen werden; die Warnung erklärt dem Anwalt den Fall.
        if (missingFields.Count == RelevantFields.Length
            && !data.KeinVersichererErmittelt
            && !data.Zwischennachricht)
        {
            return BadRequest(new ZentralrufReplyParseResponseDto(
                false,
                null,
                missingFields,
                [],
                "not_a_zentralruf_reply",
                "Im Text wurden keine Zentralruf-Antwortdaten erkannt."));
        }

        // Versicherer-Wissensbasis mitlernen lassen (auch der manuelle Weg —
        // eingefügte/geladene Antwortmails laufen nicht über den Postfach-Store).
        await versichererWissen.MerkeAusAntwortAsync(data, cancellationToken);

        return Ok(new ZentralrufReplyParseResponseDto(
            true, data, missingFields, ZentralrufReplyWarnings.Collect(data), null, null));
    }

    [HttpPost("prefill")]
    [ProducesResponseType(typeof(ZentralrufPrefillResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ZentralrufPrefillResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ZentralrufPrefillResponseDto), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<ZentralrufPrefillResponseDto>> PrefillForm([FromBody] ZentralrufPrefillDto prefillDto)
    {
        if (!ModelState.IsValid)
        {
            var errors = ModelState.Values.SelectMany(value => value.Errors).Select(error => error.ErrorMessage).ToList();
            return BadRequest(new ZentralrufPrefillResponseDto(
                false,
                null,
                [],
                [],
                "validation_failed",
                string.Join(" | ", errors)));
        }

        try
        {
            var result = await zentralrufAutomationService.PrefillAsync(prefillDto.ToDomain());
            return Ok(new ZentralrufPrefillResponseDto(true, result.Referenz, result.FilledFields, result.SkippedFields, null, null));
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Zentralruf-Formular konnte nicht vorausgefüllt werden.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new ZentralrufPrefillResponseDto(false, null, [], [], "internal_error", "Formular konnte nicht geöffnet oder vorausgefüllt werden."));
        }
    }
}
