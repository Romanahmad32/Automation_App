using AutomationService.Features.WordAutomation.Domain.Exceptions;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.WordAutomation.Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
public class WordAutomationController(
    IWordAutomationService wordAutomationService,
    VorlagenVerzeichnis vorlagenVerzeichnis,
    ArbeitsVerzeichnis arbeitsVerzeichnis,
    ILogger<WordAutomationController> logger) : ControllerBase
{
    /// <summary>
    /// Der Vorlagenordner des Anwenders samt Inhalt. Das Frontend oeffnet den
    /// Datei-Dialog in diesem Verzeichnis, statt den Anwalt nach %APPDATA%
    /// navigieren zu lassen.
    /// </summary>
    [HttpGet("vorlagen")]
    [ProducesResponseType(typeof(VorlagenUebersichtDto), StatusCodes.Status200OK)]
    public ActionResult<VorlagenUebersichtDto> GetVorlagen()
    {
        var vorlagen = vorlagenVerzeichnis.Auflisten()
            .Select(v => new VorlageDto(v.Name, v.Pfad, v.GeaendertAm))
            .ToList();

        return Ok(new VorlagenUebersichtDto(vorlagenVerzeichnis.Pfad, vorlagen));
    }

    // Typischer Fall: die Vorlage ist gerade in Word geöffnet (Sharing Violation).
    private const string FileInUseMessage =
        "Die Word-Datei kann nicht gelesen werden, weil sie gerade in einem anderen Programm " +
        "(z. B. Microsoft Word) geöffnet ist. Bitte schließen Sie die Datei und versuchen Sie es erneut.";

    // 400 hat hier zwei Formen, und das ist kein Versehen: invalid_request kommt als
    // DTO aus der Action, ein Verstoss gegen die DTO-Schranken dagegen als
    // ValidationProblemDetails — [ApiController] antwortet darauf, bevor die Action
    // ueberhaupt laeuft (siehe ValidierungsAntwort). Beide Formen liest die Dart-Seite
    // ueber backendFehlertext (message bzw. detail); der Vertrag unten nennt die
    // haeufigere. Bewusst kein ///-Kommentar: der stuende sonst als summary im Vertrag.
    [HttpPost("replaced-document")]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType(typeof(ReplacedDocumentResponseDto), StatusCodes.Status500InternalServerError)]
    public ActionResult<ReplacedDocumentResponseDto> GenerateReplacedDocument([FromBody] WordReplacementDto wordReplacementDto)
    {
        try
        {
            var result = wordAutomationService.GenerateReplacedDocument(wordReplacementDto.ToDomain());
            return Ok(new ReplacedDocumentResponseDto(true, result.OutputFilePath, result.Warnings, null, null));
        }
        catch (FileNotFoundException exception)
        {
            return NotFound(new ReplacedDocumentResponseDto(false, null, [], "template_not_found", exception.Message));
        }
        catch (ZieldateiGesperrtException exception)
        {
            logger.LogWarning(exception, "Output file is locked while generating document.");
            return Conflict(new ReplacedDocumentResponseDto(false, null, [], "output_file_in_use", exception.Message));
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
                new ReplacedDocumentResponseDto(false, null, [], "internal_error",
                    "Das Schreiben konnte nicht erzeugt werden. Der Grund steht im Protokoll des Dienstes."));
        }
    }

    /// <summary>
    /// Löscht den Arbeitsordner eines Vorgangs. Das Frontend ruft das auf,
    /// sobald das Schreiben in der Mandantenakte liegt (§4.6) — ab da ist die
    /// Kopie in der Akte die gültige Fassung, und Zwischenstände früherer
    /// Anläufe haben keinen Grund mehr, aufbewahrt zu werden.
    /// </summary>
    [HttpPost("arbeitsordner/aufraeumen")]
    [ProducesResponseType(typeof(ArbeitsordnerAufgeraeumtDto), StatusCodes.Status200OK)]
    public ActionResult<ArbeitsordnerAufgeraeumtDto> ArbeitsordnerAufraeumen([FromBody] ArbeitsordnerDto dto)
    {
        var aufgeraeumt = arbeitsVerzeichnis.Aufraeumen(dto.VorgangSchluessel);
        return Ok(new ArbeitsordnerAufgeraeumtDto(
            aufgeraeumt,
            aufgeraeumt
                ? null
                : "Die Arbeitskopie konnte nicht gelöscht werden, weil sie noch geöffnet ist. " +
                  "Das abgelegte Dokument in der Akte ist davon nicht betroffen."));
    }

    /// <summary>
    /// Berechnet die RVG-Anwaltskosten für die Live-Vorschau der Schadensaufstellung.
    /// Zustandslos und schnell – das Frontend ruft den Endpoint debounced bei jeder
    /// Eingabeänderung auf, damit Vorschau und erzeugtes Dokument identisch rechnen.
    /// </summary>
    [HttpPost("rvg-calculation")]
    [ProducesResponseType(typeof(RvgCalculationResponseDto), StatusCodes.Status200OK)]
    // Der einzige 400 dieses Endpunkts ist der Verstoss gegen die Schranken der
    // Anfrage, und den beantwortet [ApiController] in ProblemDetails-Form.
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    public ActionResult<RvgCalculationResponseDto> CalculateRvgFees([FromBody] RvgCalculationRequestDto requestDto)
    {
        try
        {
            var calculation = RvgFeeCalculator.Calculate(
                // Nicht null: [Required] haelt die Anfrage ohne Feld schon vorher auf.
                requestDto.Gegenstandswert!.Value,
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
                new TemplatePlaceholdersResponseDto(false, [], "internal_error",
                    "Die Platzhalter der Vorlage konnten nicht gelesen werden. Der Grund steht im Protokoll des Dienstes."));
        }
    }
}
