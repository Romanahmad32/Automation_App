using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.EmailVersand.Presentation.Controllers;

/// <summary>
/// Versendet die fertig verfasste Mail zum Vorgang (REQUIREMENTS.md §4.7).
/// Verfasst wird in der Oberfläche; dieser Endpunkt bekommt sie fertig und
/// übergibt sie dem Postausgangsserver der Kanzlei.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class EmailVersandController(
    IEmailVersender versender,
    IEntwurfOeffner oeffner,
    OutlookVerbindung outlook,
    AnhangAblage ablage,
    SignaturUebernahme signaturUebernahme,
    SignaturAblage signaturAblage,
    OutlookErkennung outlookErkennung,
    KanzleiSignatur signatur) : ControllerBase
{
    /// <summary>
    /// Meldet, ob gesendet werden kann und von welcher Adresse aus. Die
    /// Oberfläche fragt das ab, bevor der Anwalt zu tippen beginnt.
    /// </summary>
    [HttpGet("bereitschaft")]
    [ProducesResponseType(typeof(EmailVersandBereitschaftDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<EmailVersandBereitschaftDto>> GetBereitschaft(
        CancellationToken cancellationToken)
    {
        var bereitschaft = await versender.PruefeBereitschaftAsync(cancellationToken);
        return Ok(EmailVersandBereitschaftDto.From(bereitschaft));
    }

    /// <summary>
    /// Meldet die Signaturen, die im Outlook dieses Rechners eingerichtet
    /// sind (§4.7). Zum einmaligen Übernehmen in die Einstellungen — danach
    /// hängt der Versand nicht mehr an Outlook. Eine leere Liste heißt: hier
    /// ist keine eingerichtet, und das ist kein Fehler.
    /// </summary>
    [HttpGet("signaturen")]
    [ProducesResponseType(typeof(IReadOnlyList<OutlookSignaturDto>), StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<OutlookSignaturDto>> GetSignaturen() =>
        Ok(OutlookSignaturen.Lies().Select(OutlookSignaturDto.From).ToList());

    /// <summary>
    /// Die Signatur, wie sie gerade in den Einstellungen liegt (§4.7) — mit
    /// ihren Bildern und deren Größe. Die Einstellungsmaske zeigt daraus, was
    /// unter jeder Mail steht und was es wiegt; die HTML-Fassung selbst geht
    /// bewusst nicht über die Leitung.
    /// </summary>
    [HttpGet("signaturen/stand")]
    [ProducesResponseType(typeof(SignaturStandDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SignaturStandDto>> GetSignaturStand(
        CancellationToken cancellationToken) =>
        Ok(SignaturStandDto.From(await signatur.BlockAsync(cancellationToken)));

    /// <summary>
    /// Ein einzelnes Bild der übernommenen Signatur (§4.7). Die Oberfläche
    /// zeigt damit in der Vorschau, was wirklich unter der Mail steht — den
    /// Signaturtext allein anzuzeigen hieße, das Logo erst im Ordner
    /// "Gesendet" zu sehen.
    ///
    /// Ausgeliefert wird nur, was in der Signaturablage liegt: Der Name kommt
    /// von aussen, <see cref="SignaturAblage.PfadVon"/> lässt deshalb keinen
    /// Pfad durch, der aus diesem einen Ordner hinausführt.
    /// </summary>
    [HttpGet("signaturen/bild")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public IActionResult GetSignaturBild([FromQuery] string? dateiname)
    {
        var pfad = signaturAblage.PfadVon(dateiname ?? string.Empty);
        return pfad is null
            ? NotFound()
            : PhysicalFile(pfad, SignaturAblage.InhaltsArt(pfad));
    }

    /// <summary>
    /// Übernimmt die gewählte Signatur in die Einstellungen (§4.7): Text,
    /// formatierte Fassung und deren Bilder in einem Zug. Das geschieht hier
    /// und nicht in der Oberfläche, weil die Bilder abgelegt werden müssen und
    /// die HTML-Fassung zehntausende Zeichen groß ist.
    /// </summary>
    [HttpPost("signaturen/uebernehmen")]
    [ProducesResponseType(typeof(SignaturStandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SignaturStandDto>> SignaturUebernehmen(
        [FromBody] SignaturUebernahmeDto anfrage,
        CancellationToken cancellationToken)
    {
        try
        {
            var (block, uebergangen) = await signaturUebernahme.UebernimmAsync(
                anfrage.Name ?? string.Empty,
                cancellationToken);
            return Ok(SignaturStandDto.From(block, uebergangen));
        }
        catch (EmailVersandException exception)
        {
            return Problem(
                title: "Die Signatur wurde nicht übernommen",
                detail: exception.Message,
                statusCode: StatusCodes.Status400BadRequest);
        }
    }

    /// <summary>
    /// Wirft die formatierte Fassung samt Bildern weg; die Nur-Text-Fassung
    /// bleibt stehen (§4.7). Für den Anwalt, dem die übernommene Formatierung
    /// nicht gefällt — ohne diesen Weg käme er nur durch eine andere Übernahme
    /// wieder heraus.
    /// </summary>
    [HttpDelete("signaturen/format")]
    [ProducesResponseType(typeof(SignaturStandDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SignaturStandDto>> SignaturFormatVerwerfen(
        CancellationToken cancellationToken)
    {
        var block = await signaturUebernahme.VerwirfFormatAsync(cancellationToken);
        return Ok(SignaturStandDto.From(block));
    }

    /// <summary>
    /// Sendet die Mail. Entweder ganz oder gar nicht: Bei einem Fehler ist
    /// nichts hinausgegangen, und der Grund steht im Klartext in den
    /// ProblemDetails.
    /// </summary>
    [HttpPost("senden")]
    [ProducesResponseType(typeof(EmailVersandErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<EmailVersandErgebnisDto>> Senden(
        [FromBody] EmailVersandDto anfrage,
        CancellationToken cancellationToken)
    {
        try
        {
            var ergebnis = await versender.SendeAsync(anfrage.ToDomain(), cancellationToken);
            return Ok(EmailVersandErgebnisDto.From(ergebnis));
        }
        catch (EmailVersandException exception)
        {
            return Problem(
                title: "Die E-Mail wurde nicht versendet",
                detail: exception.Message,
                statusCode: StatusFuer(exception.Grund));
        }
    }

    /// <summary>
    /// Welches Outlook auf diesem Rechner steht (§4.7). Beim Start einmal
    /// ermittelt, hier nur abgeholt.
    ///
    /// Die Oberfläche fragt das, bevor sie Knöpfe anbietet, die das klassische
    /// Outlook brauchen: Ohne dieses tun der Anhang-Griff und die
    /// Signatur-Übernahme still nichts, und der Entwurf geht als Datei auf.
    /// Jedes für sich sieht aus wie ein Aussetzer.
    /// </summary>
    [HttpGet("outlook/stand")]
    [ProducesResponseType(typeof(OutlookStandDto), StatusCodes.Status200OK)]
    public ActionResult<OutlookStandDto> GetOutlookStand() =>
        Ok(OutlookStandDto.From(outlookErkennung.Stand));

    /// <summary>
    /// Startet Outlook im Hintergrund, damit der erste Entwurf den Kaltstart
    /// nicht bezahlt (§4.7). Die Oberfläche ruft das beim Öffnen des
    /// Versanddialogs — bis der Anwalt fertig getippt hat, steht Outlook.
    /// Antwortet sofort und meldet nie einen Fehler: Misslingt es, ist der
    /// Entwurfsweg deswegen nicht kaputt, nur wieder langsam.
    /// </summary>
    [HttpPost("entwurf/vorwaermen")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public IActionResult EntwurfVorwaermen()
    {
        outlook.WaermeVor();
        return NoContent();
    }

    /// <summary>
    /// Die Anhänge der Nachricht, die in Outlook gerade offen oder ausgewählt
    /// ist (§4.7). Beobachtet wurde, dass genau diese Dateien im Mailprogramm
    /// von Hand in die ausgehende Nachricht gezogen werden — die App fragt
    /// stattdessen nach. Leere Liste heißt: nichts ausgewählt oder nichts
    /// dran, und das ist kein Fehler.
    ///
    /// Betreff und Absender gehen mit zurück: Welche Nachricht gelesen wurde,
    /// entscheidet Outlook, nicht der Anwalt — er soll es wenigstens erfahren.
    ///
    /// Der COM-Aufruf wartet bei kaltem Outlook bis zu 90 Sekunden — wie beim
    /// Entwurf (<see cref="EntwurfOeffner"/>) gehört er deshalb nicht auf den
    /// Thread, der die Anfrage bedient.
    /// </summary>
    [HttpGet("outlook/anhaenge")]
    [ProducesResponseType(typeof(OutlookAnhaengeDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<OutlookAnhaengeDto>> GetOutlookAnhaenge(
        CancellationToken cancellationToken) =>
        Ok(OutlookAnhaengeDto.From(
            await Task.Run(outlook.AnhaengeDerAuswahl, cancellationToken)));

    /// <summary>
    /// Wirft eine aus Outlook geholte Datei weg (§4.7). Der Anwalt verwirft
    /// damit einen Vorschlag, den er nicht braucht — die Datei soll dann auch
    /// nicht liegen bleiben. Nur dieser eine Ordner; die Anhänge erfasster
    /// Antworten daneben bleiben unberührt (§4.3). 204 auch dann, wenn schon
    /// nichts mehr da war.
    /// </summary>
    [HttpDelete("outlook/anhaenge")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public IActionResult AnhangVerwerfen([FromQuery] string pfad)
    {
        if (ablage.VerwirfGeholten(pfad))
        {
            return NoContent();
        }

        return Problem(
            title: "Der Anhang wurde nicht gelöscht",
            detail: "Die Datei wurde nicht aus einer Outlook-Nachricht geholt.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    /// <summary>
    /// Öffnet die Mail als Entwurf im Mailprogramm, statt sie zu senden
    /// (§4.7). Gesendet wird dort von Hand — die App erfährt davon nichts
    /// mehr, deshalb bleibt das Häkchen beim Abschluss manuell (§4.8).
    /// </summary>
    [HttpPost("entwurf")]
    [ProducesResponseType(typeof(EntwurfErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<EntwurfErgebnisDto>> Entwurf(
        [FromBody] EmailVersandDto anfrage,
        CancellationToken cancellationToken)
    {
        try
        {
            var ergebnis = await oeffner.OeffneAsync(anfrage.ToDomain(), cancellationToken);
            return Ok(EntwurfErgebnisDto.From(ergebnis));
        }
        catch (EmailVersandException exception)
        {
            return Problem(
                title: "Der Entwurf wurde nicht geöffnet",
                detail: exception.Message,
                statusCode: StatusFuer(exception.Grund));
        }
    }

    /// <summary>
    /// Was der Anwalt selbst beheben kann, ist eine 400 — was der Server
    /// verweigert hat, eine 502. Die Unterscheidung entscheidet in der
    /// Oberfläche darüber, ob ein erneuter Versuch überhaupt Sinn hat.
    /// </summary>
    private static int StatusFuer(EmailVersandFehler grund) => grund switch
    {
        EmailVersandFehler.Anmeldung
            or EmailVersandFehler.Server
            or EmailVersandFehler.Entwurf => StatusCodes.Status502BadGateway,
        _ => StatusCodes.Status400BadRequest,
    };
}
