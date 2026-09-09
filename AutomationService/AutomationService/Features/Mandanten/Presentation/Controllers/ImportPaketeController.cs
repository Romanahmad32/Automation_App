using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// Die Buchführung über die Arbeitspakete des Mandanten-Imports (§5.1, §6.1).
///
/// Zusammengesetzt wird ein Paket im Frontend — nur dort ist der Ordnerbestand
/// im Dateisystem bekannt —, hier wird es nur verbucht, wieder ausgelesen und
/// — solange es offen ist — zurückgenommen. Es gibt keine Route, die ein
/// Paket als eingelesen meldet: Das rechnet der Import selbst aus den
/// Ordnernamen aus, damit der Anwalt beim Import nichts auszuwählen hat.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ImportPaketeController(IImportPaketBuch buch) : ControllerBase
{
    /// <summary>Alle Pakete, das jüngste zuerst.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ImportPaketDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ImportPaketDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var pakete = await buch.GetAllAsync(cancellationToken);
        return Ok(pakete.Select(ImportPaketDto.From).ToList());
    }

    /// <summary>
    /// Verbucht ein herausgegebenes Paket und antwortet mit ihm samt der
    /// vergebenen Nummer — die Oberfläche nennt sie dem Anwalt und schreibt
    /// sie in den Dateinamen.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ImportPaketDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ImportPaketDto>> Notiere(
        [FromBody] NotiereImportPaketDto dto,
        CancellationToken cancellationToken)
    {
        try
        {
            var stand = await buch.NotiereAsync(dto.Ordnernamen, cancellationToken);
            return Ok(ImportPaketDto.From(stand));
        }
        catch (ArgumentException exception)
        {
            return Problem(detail: exception.Message, statusCode: StatusCodes.Status400BadRequest);
        }
    }

    /// <summary>
    /// Nimmt ein versehentlich herausgegebenes, noch offenes Paket zurück.
    /// Rührt keinen Ordner an — das Paket war nur eine Buchführungszeile.
    /// </summary>
    [HttpDelete("{nummer:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Loesche(int nummer, CancellationToken cancellationToken)
    {
        try
        {
            var geloescht = await buch.LoescheAsync(nummer, cancellationToken);
            return geloescht
                ? NoContent()
                : Problem(detail: $"Paket {nummer} nicht gefunden", statusCode: StatusCodes.Status404NotFound);
        }
        catch (InvalidOperationException exception)
        {
            return Problem(detail: exception.Message, statusCode: StatusCodes.Status409Conflict);
        }
    }
}
