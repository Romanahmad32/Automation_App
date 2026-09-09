using AutomationService.Features.RegisterHistorie.Domain.Services;
using AutomationService.Features.RegisterHistorie.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.RegisterHistorie.Presentation.Controllers;

/// <summary>
/// Übernahme des gewachsenen Kanzleiregisters ab 2018 in Jahrgängen (§6.2).
///
/// Ein Endpunkt, zwei Betriebsarten — und die schreibende ist nicht die
/// voreingestellte: ohne <c>uebernehmen=true</c> wird nur geprüft. Eine
/// abgeschickte Datei kann damit nichts verändern, solange niemand ausdrücklich
/// zustimmt; das ist derselbe Haltepunkt wie vor dem Versand eines Schreibens.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class RegisterImportController(IRegisterImport import) : ControllerBase
{
    /// <summary>Die einzige Formatfassung, die dieser Dienst lesen kann.</summary>
    public const int UnterstuetzteVersion = 1;

    [HttpPost]
    [ProducesResponseType(typeof(RegisterImportBerichtDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RegisterImportBerichtDto>> Importiere(
        [FromBody] RegisterImportDto datei,
        [FromQuery] bool uebernehmen,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(datei);

        var version = datei.Version ?? UnterstuetzteVersion;
        if (version != UnterstuetzteVersion)
        {
            return Problem(
                detail: $"Importformat der Fassung {version} kann nicht gelesen werden — " +
                    $"erwartet wird {UnterstuetzteVersion}.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var auftrag = new RegisterImportAuftrag(datei.ZuDomaene(), NurPruefen: !uebernehmen);
        var befund = await import.FuehreAusAsync(auftrag, cancellationToken);
        return Ok(RegisterImportBerichtDto.From(befund));
    }
}
