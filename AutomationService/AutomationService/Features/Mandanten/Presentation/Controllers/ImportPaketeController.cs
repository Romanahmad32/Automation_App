using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// Die Buchführung über die Arbeitspakete des Mandanten-Imports (§5.1, §6.1).
///
/// Zwei Routen genügen, und beide sind bewusst schmal: Zusammengesetzt wird
/// ein Paket im Frontend — nur dort ist der Ordnerbestand im Dateisystem
/// bekannt —, hier wird es nur verbucht und wieder ausgelesen. Es gibt keine
/// Route, die ein Paket als eingelesen meldet: Das rechnet der Import selbst
/// aus den Ordnernamen aus, damit der Anwalt beim Import nichts auszuwählen
/// hat.
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
    [ProducesResponseType(StatusCodes.Status409Conflict)]
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
        catch (DbUpdateException)
        {
            // Der Unique-Index auf `Nummer` (ImportPaketEntityConfiguration) ist
            // der Wächter über die Vergabe „Maximum + 1": Kommt ein zweiter
            // Aufruf dazwischen, bevor dieser sein SaveChanges abgeschlossen hat,
            // verletzt einer der beiden den Index. Das ist kein falscher Auftrag
            // wie bei ArgumentException, sondern ein vorübergehender Zusammenstoß
            // — ein erneuter Versuch vergibt die nächste freie Nummer.
            return Problem(
                detail: "Die Paketnummer wurde soeben anderweitig vergeben — bitte erneut versuchen.",
                statusCode: StatusCodes.Status409Conflict);
        }
    }
}
