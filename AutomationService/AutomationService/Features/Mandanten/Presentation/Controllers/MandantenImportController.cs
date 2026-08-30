using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// Übernahme eines maschinell erzeugten Abbilds des Aktenbestands ins Register
/// (§5.1/§6.1). Das Format beschreibt <c>docs/MANDANTEN_IMPORT.md</c>.
///
/// Ein Endpunkt, zwei Betriebsarten — und die schreibende ist nicht die
/// voreingestellte: ohne <c>uebernehmen=true</c> wird nur geprüft. Eine
/// abgeschickte Datei kann damit nichts verändern, solange niemand ausdrücklich
/// zustimmt; das ist derselbe Haltepunkt wie vor dem Versand eines Schreibens.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MandantenImportController(IMandantenImport import) : ControllerBase
{
    /// <summary>Die einzige Formatfassung, die dieser Dienst lesen kann.</summary>
    public const int UnterstuetzteVersion = 1;

    [HttpPost]
    [ProducesResponseType(typeof(ImportBerichtDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ImportBerichtDto>> Importiere(
        [FromBody] MandantenImportDto datei,
        [FromQuery] bool uebernehmen,
        CancellationToken cancellationToken)
    {
        var version = datei.Version ?? UnterstuetzteVersion;
        if (version != UnterstuetzteVersion)
        {
            return BadRequest(
                $"Importformat der Fassung {version} kann nicht gelesen werden — " +
                $"erwartet wird {UnterstuetzteVersion}.");
        }

        var auftrag = new MandantenImportAuftrag(
            [.. (datei.Mandanten ?? []).Select(eintrag => eintrag.ZuDomaene())],
            datei.OhneMandantenbezug ?? [],
            NurPruefen: !uebernehmen);

        var befund = await import.FuehreAusAsync(auftrag, cancellationToken);
        return Ok(ImportBerichtDto.From(befund));
    }
}
