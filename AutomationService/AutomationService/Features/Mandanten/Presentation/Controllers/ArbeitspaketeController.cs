using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// Das Buch über die Arbeitspakete des Mandanten-Imports (§5.1/§6.1). Zwei
/// Routen genügen: die Historie lesen und das nächste Paket holen.
///
/// Der Bestand kommt mit der Anfrage herein, statt hier ermittelt zu werden —
/// die Ordner liegen im Dateisystem, und das gehört dem Frontend. Das Backend
/// steuert bei, was es allein weiß: welche Ordner schon zugeordnet oder
/// vermerkt sind, in welcher Reihenfolge die übrigen abgearbeitet werden und
/// welches Paket wann herausging.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ArbeitspaketeController(IArbeitspaketBuch buch) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ArbeitspaketDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ArbeitspaketDto>>> GetAll(
        CancellationToken cancellationToken)
    {
        var pakete = await buch.GetAllAsync(cancellationToken);
        return Ok(pakete.Select(ArbeitspaketDto.From).ToList());
    }

    /// <summary>
    /// Gibt das nächste Paket heraus und schreibt es ins Buch. Bewusst
    /// schreibend und damit ein <c>POST</c>: „geholt am" ist die halbe Auskunft,
    /// die das Buch überhaupt geben soll.
    ///
    /// Ist nichts mehr offen, kommt 409 statt eines leeren Pakets — die
    /// <see cref="KeineOffenenOrdnerException"/> übersetzt der
    /// <c>FachExceptionHandler</c>, wie den Namenskonflikt nebenan auch.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ArbeitspaketDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<ArbeitspaketDto>> Hole(
        [FromBody] ArbeitspaketAnfrageDto anfrage,
        CancellationToken cancellationToken)
    {
        // Ohne Bestand wäre jedes Paket leer. Das als Erfolg zu quittieren
        // hieße, eine Nummer zu vergeben für eine Anfrage, die den Scan des
        // Akten-Stammordners vergessen hat.
        if (anfrage.Ordnernamen is not { Count: > 0 })
        {
            return Problem(
                detail: "Ohne Ordnernamen lässt sich kein Arbeitspaket bilden — " +
                    "der Bestand des Akten-Stammordners gehört mit in die Anfrage.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var paket = await buch.HoleAsync(
            anfrage.Ordnernamen, anfrage.Groesse(), cancellationToken);
        return Ok(ArbeitspaketDto.From(paket));
    }
}
