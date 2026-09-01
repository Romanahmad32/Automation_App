using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.PdfConversion.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.PdfConversion.Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PdfConversionController(IPdfConversionService pdfService, ILogger<PdfConversionController> logger)
    : ControllerBase
{
    [HttpPost("convert")]
    public async Task<IActionResult> ConvertDocxToPdf(IFormFile docxFile)
    {
        if (docxFile == null || docxFile.Length == 0)
        {
            return Problem(detail: "Keine Datei übermittelt.", statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            using var memoryStream = new MemoryStream();
            await docxFile.CopyToAsync(memoryStream);
            byte[] docxBytes = memoryStream.ToArray();

            byte[] pdfBytes = await pdfService.ConvertDocxToPdfFromBytesAsync(docxBytes);

            return File(pdfBytes, "application/pdf", $"{Path.GetFileNameWithoutExtension(docxFile.FileName)}.pdf");
        }
        catch (Exception ex) when (ex is not PdfConversionUnavailableException)
        {
            logger.LogError(ex, "Fehler bei der Umwandlung von DOCX nach PDF.");
            return Problem(
                detail: "Die Umwandlung nach PDF ist fehlgeschlagen.",
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }

    [HttpPost("convert-from-path")]
    public async Task<IActionResult> ConvertDocxToPdfFromPath([FromBody] ConvertFromPathRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.DocxFilePath))
        {
            return Problem(
                detail: "Der Pfad zur DOCX-Datei fehlt.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            byte[] pdfBytes = await pdfService.ConvertDocxToPdfAsync(request.DocxFilePath);

            var fileName = Path.GetFileNameWithoutExtension(request.DocxFilePath);
            return File(pdfBytes, "application/pdf", $"{fileName}.pdf");
        }
        catch (FileNotFoundException ex)
        {
            logger.LogError(ex, "DOCX-Datei nicht gefunden.");
            return Problem(
                detail: $"Datei nicht gefunden: {ex.Message}",
                statusCode: StatusCodes.Status404NotFound);
        }
        catch (Exception ex) when (ex is not PdfConversionUnavailableException)
        {
            logger.LogError(ex, "Fehler bei der Umwandlung von DOCX nach PDF.");
            return Problem(
                detail: "Die Umwandlung nach PDF ist fehlgeschlagen.",
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }
}
