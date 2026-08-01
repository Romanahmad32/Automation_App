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
            return BadRequest("No file provided.");

        try
        {
            using var memoryStream = new MemoryStream();
            await docxFile.CopyToAsync(memoryStream);
            byte[] docxBytes = memoryStream.ToArray();

            byte[] pdfBytes = await pdfService.ConvertDocxToPdfFromBytesAsync(docxBytes);

            return File(pdfBytes, "application/pdf", $"{Path.GetFileNameWithoutExtension(docxFile.FileName)}.pdf");
        }
        catch (PdfConversionUnavailableException ex)
        {
            logger.LogError(ex, "PDF conversion unavailable.");
            return StatusCode(503, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error converting DOCX to PDF.");
            return StatusCode(500, "Conversion failed.");
        }
    }

    [HttpPost("convert-from-path")]
    public async Task<IActionResult> ConvertDocxToPdfFromPath([FromBody] ConvertFromPathRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.DocxFilePath))
            return BadRequest("DocX file path is required.");

        try
        {
            byte[] pdfBytes = await pdfService.ConvertDocxToPdfAsync(request.DocxFilePath);

            var fileName = Path.GetFileNameWithoutExtension(request.DocxFilePath);
            return File(pdfBytes, "application/pdf", $"{fileName}.pdf");
        }
        catch (FileNotFoundException ex)
        {
            logger.LogError(ex, "DOCX file not found.");
            return NotFound($"File not found: {ex.Message}");
        }
        catch (PdfConversionUnavailableException ex)
        {
            logger.LogError(ex, "PDF conversion unavailable.");
            return StatusCode(503, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error converting DOCX to PDF.");
            return StatusCode(500, "Conversion failed.");
        }
    }
}
