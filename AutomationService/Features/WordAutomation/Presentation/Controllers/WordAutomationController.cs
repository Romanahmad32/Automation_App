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
    [HttpPost("replaced-document")]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status404NotFound)]
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
}
