using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Aktualisierung.Presentation.Controllers;

/// <summary>
/// Aktualisierung aus der App heraus (#196): Der Dienst prüft, lädt, prüft
/// nach und startet den Installer — nicht das Frontend, weil nur der Dienst
/// System-Proxy und Windows-Zertifikate nutzt. Jede Antwort trägt den ganzen
/// Stand; eine Ablehnung ist ein 409 mit deutscher Meldung, den neuen Stand
/// holt das Frontend dann über <c>GET</c>.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AktualisierungController(IAktualisierungsDienst dienst) : ControllerBase
{
    /// <summary>Der zwischengespeicherte Stand; billig, wird während des Downloads abgefragt.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(AktualisierungsStandDto), StatusCodes.Status200OK)]
    public ActionResult<AktualisierungsStandDto> Stand() =>
        Ok(AktualisierungsStandDto.From(dienst.Stand()));

    /// <summary>
    /// Fragt die Update-Quelle. Ein Fehler dabei ist kein HTTP-Fehler, sondern
    /// der Zustand <c>unbekannt</c> mit Meldung.
    /// </summary>
    [HttpPost("pruefen")]
    [ProducesResponseType(typeof(AktualisierungsStandDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AktualisierungsStandDto>> Pruefen(CancellationToken cancellationToken) =>
        Ok(AktualisierungsStandDto.From(await dienst.PruefeAsync(cancellationToken)));

    /// <summary>Startet den Download im Hintergrund; idempotent bei <c>laedt</c> und <c>bereit</c>.</summary>
    [HttpPost("herunterladen")]
    [ProducesResponseType(typeof(AktualisierungsStandDto), StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public ActionResult<AktualisierungsStandDto> Herunterladen() => Angenommen(dienst.StarteDownload());

    /// <summary>Bricht den Download ab; die Teildatei ist danach gelöscht.</summary>
    [HttpPost("abbrechen")]
    [ProducesResponseType(typeof(AktualisierungsStandDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AktualisierungsStandDto>> Abbrechen() =>
        Ok(AktualisierungsStandDto.From(await dienst.BrecheAbAsync()));

    /// <summary>
    /// Prüft die Setup-Datei erneut, startet den Installer losgelöst und sieht
    /// drei Sekunden hin, ob er läuft. Danach beendet das Frontend die App, und
    /// der Dienst fährt nach wenigen Sekunden selbst geordnet herunter; das Setup
    /// wartet, bis er fort ist. Beendet sich das Setup sofort wieder, ist das ein
    /// 409 mit Zustand fehler, und der Dienst bleibt an. Außerhalb der
    /// installierten App lehnt er mit 409 ab und startet nichts.
    /// </summary>
    [HttpPost("installieren")]
    [ProducesResponseType(typeof(AktualisierungsStandDto), StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public ActionResult<AktualisierungsStandDto> Installieren() => Angenommen(dienst.Installiere());

    /// <summary>Das Frontend hat das Ergebnis der letzten Aktualisierung gezeigt.</summary>
    [HttpPost("ergebnis-quittieren")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public IActionResult ErgebnisQuittieren()
    {
        dienst.QuittiereErgebnis();
        return NoContent();
    }

    private ActionResult<AktualisierungsStandDto> Angenommen(AktualisierungsSchritt schritt) =>
        schritt.Ablehnung is { } ablehnung
            ? Problem(detail: ablehnung, statusCode: StatusCodes.Status409Conflict)
            : StatusCode(StatusCodes.Status202Accepted, AktualisierungsStandDto.From(schritt.Stand));
}
