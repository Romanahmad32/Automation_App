using AutomationService.Features.WordAutomation.Domain.Exceptions;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.WordAutomation.Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
public class WordAutomationController(
    IWordAutomationService wordAutomationService,
    ILogger<WordAutomationController> logger) : ControllerBase
{
    // Typischer Fall: die Vorlage ist gerade in Word geöffnet (Sharing Violation).
    private const string FileInUseMessage =
        "Die Word-Datei kann nicht gelesen werden, weil sie gerade in einem anderen Programm " +
        "(z. B. Microsoft Word) geöffnet ist. Bitte schließen Sie die Datei und versuchen Sie es erneut.";

    [HttpPost("replaced-document")]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status500InternalServerError)]
    public ActionResult<ReplacedDocumentResponseDto> GenerateReplacedDocument([FromBody] WordReplacementDto wordReplacementDto)
    {
        if (!ModelState.IsValid)
        {
            var errors = ModelState.Values.SelectMany(value => value.Errors).Select(error => error.ErrorMessage).ToList();
            return BadRequest(new ReplacedDocumentResponseDto(
                false,
                null,
                [],
                "validation_failed",
                string.Join(" | ", errors)));
        }

        try
        {
            var result = wordAutomationService.GenerateReplacedDocument(wordReplacementDto);
            return Ok(new ReplacedDocumentResponseDto(true, result.OutputFilePath, result.Warnings, null, null));
        }
        catch (FileNotFoundException exception)
        {
            return NotFound(new ReplacedDocumentResponseDto(false, null, [], "template_not_found", exception.Message));
        }
        catch (IOException exception)
        {
            logger.LogWarning(exception, "Template file is locked while generating document.");
            return Conflict(new ReplacedDocumentResponseDto(false, null, [], "file_in_use", FileInUseMessage));
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new ReplacedDocumentResponseDto(false, null, [], "invalid_request", exception.Message));
        }
        catch (TemplateProcessingException exception)
        {
            logger.LogWarning(exception, "Template processing error while generating document.");
            return UnprocessableEntity(new ReplacedDocumentResponseDto(false, null, [], "template_processing_failed", exception.Message));
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unexpected failure while generating replaced document.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new ReplacedDocumentResponseDto(false, null, [], "internal_error", "Unexpected error while generating document."));
        }
    }

    /// <summary>
    /// Berechnet die RVG-Anwaltskosten für die Live-Vorschau der Schadensaufstellung.
    /// Zustandslos und schnell – das Frontend ruft den Endpoint debounced bei jeder
    /// Eingabeänderung auf, damit Vorschau und erzeugtes Dokument identisch rechnen.
    /// </summary>
    [HttpPost("rvg-calculation")]
    [ProducesResponseType(typeof(RvgCalculationResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(RvgCalculationResponseDto), StatusCodes.Status400BadRequest)]
    public ActionResult<RvgCalculationResponseDto> CalculateRvgFees([FromBody] RvgCalculationRequestDto requestDto)
    {
        if (!ModelState.IsValid)
        {
            var errors = ModelState.Values.SelectMany(value => value.Errors).Select(error => error.ErrorMessage).ToList();
            return BadRequest(new RvgCalculationResponseDto(
                false, 0, 0, 0, 0, 0, 0, 0, 0, "validation_failed", string.Join(" | ", errors)));
        }

        try
        {
            var calculation = RvgFeeCalculator.Calculate(
                requestDto.Gegenstandswert,
                requestDto.Gebuehrensatz,
                requestDto.ApplyVat,
                requestDto.GeschaeftsgebuehrOverride,
                requestDto.AuslagenpauschaleOverride);
            return Ok(new RvgCalculationResponseDto(
                true,
                calculation.Gegenstandswert,
                calculation.Gebuehrensatz,
                calculation.Wertgebuehr,
                calculation.Geschaeftsgebuehr,
                calculation.Auslagenpauschale,
                calculation.Netto,
                calculation.Umsatzsteuer,
                calculation.Brutto,
                null,
                null));
        }
        catch (ArgumentOutOfRangeException exception)
        {
            return BadRequest(new RvgCalculationResponseDto(
                false, 0, 0, 0, 0, 0, 0, 0, 0, "invalid_request", exception.Message));
        }
    }

    /// <summary>
    /// Liest die {{Platzhalter}} einer Word-Vorlage aus, damit das Frontend sie beim
    /// Anlegen/Bearbeiten einer Formularvorlage anzeigen kann. POST mit JSON-Body,
    /// weil Windows-Pfade als Query-Parameter unhandlich sind (analog PdfConversion).
    /// </summary>
    [HttpPost("template-placeholders")]
    [ProducesResponseType(typeof(TemplatePlaceholdersResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(TemplatePlaceholdersResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(TemplatePlaceholdersResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(TemplatePlaceholdersResponseDto), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(TemplatePlaceholdersResponseDto), StatusCodes.Status500InternalServerError)]
    public ActionResult<TemplatePlaceholdersResponseDto> GetTemplatePlaceholders(
        [FromBody] TemplatePlaceholdersRequestDto requestDto)
    {
        try
        {
            var placeholders = wordAutomationService.ExtractPlaceholders(requestDto.TemplateFilePath);
            return Ok(new TemplatePlaceholdersResponseDto(true, placeholders, null, null));
        }
        catch (FileNotFoundException exception)
        {
            return NotFound(new TemplatePlaceholdersResponseDto(false, [], "template_not_found", exception.Message));
        }
        catch (IOException exception)
        {
            logger.LogWarning(exception, "Template file is locked while extracting placeholders.");
            return Conflict(new TemplatePlaceholdersResponseDto(false, [], "file_in_use", FileInUseMessage));
        }
        catch (ArgumentException exception)
        {
            return BadRequest(new TemplatePlaceholdersResponseDto(false, [], "invalid_request", exception.Message));
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unexpected failure while extracting template placeholders.");
            return StatusCode(
                StatusCodes.Status500InternalServerError,
                new TemplatePlaceholdersResponseDto(false, [], "internal_error", "Unexpected error while reading template placeholders."));
        }
    }
}
