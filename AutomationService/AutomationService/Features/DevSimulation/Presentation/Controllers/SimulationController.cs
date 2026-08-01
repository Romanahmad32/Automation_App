using System.Globalization;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.DevSimulation.Presentation.Dtos;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Dtos;
using AutomationService.Features.MailboxMonitor.Presentation.Hubs;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.DevSimulation.Presentation.Controllers;

/// <summary>
/// Entwickler-Simulation (nur bei <c>Simulation:Enabled</c>, d. h. im
/// Development-Profil; sonst 404): speist eine synthetische Zentralruf-Antwort
/// in die <b>echte</b> Postfach-Pipeline ein — Mailtext bauen, mit dem echten
/// Parser auswerten, im ReceivedReplyStore ablegen und per SignalR pushen.
/// Für die App ist der Treffer von einem echten IMAP-Fund nicht zu
/// unterscheiden; Übernahme, Vorlagen-Ausfüllung usw. laufen den normalen Weg.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SimulationController(
    IOptions<SimulationOptions> options,
    IZentralrufReplyParser parser,
    IReceivedReplyStore store,
    MailboxConnectionState state,
    IHubContext<MailboxHub> hub) : ControllerBase
{
    [HttpPost("zentralruf-antwort")]
    [ProducesResponseType(typeof(ReceivedReplyDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ReceivedReplyDto>> SimuliereZentralrufAntwort(
        [FromBody] SimulationAntwortRequestDto dto,
        CancellationToken cancellationToken)
    {
        if (!options.Value.Enabled) return NotFound();
        if (string.IsNullOrWhiteSpace(dto.Referenz))
        {
            return BadRequest("Die Referenz darf nicht leer sein.");
        }

        var referenz = dto.Referenz.Trim();
        var text = ZentralrufAntwortMailBuilder.Build(
            referenz,
            kennzeichen: Fallback(dto.Kennzeichen, KennzeichenAusReferenz(referenz)),
            unfallDatum: Fallback(dto.UnfallDatum, DateTime.Today.AddDays(-14).ToString("dd.MM.yyyy", CultureInfo.InvariantCulture)),
            anfrageDatum: DateTime.Today.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture),
            versichererName: Fallback(dto.VersichererName, "HUK-COBURG (Simulation)"),
            typ: dto.AntwortTyp);

        var data = parser.Parse(text);
        var warnings = ZentralrufReplyWarnings.Collect(data);

        var reply = await store.AddAsync(
            dedupeKey: $"simulation:{Guid.NewGuid():N}",
            data,
            subject: $"Antwort von Zentralruf: Ihre Anfrage mit Zeichen {referenz} (SIMULIERT)",
            from: "Entwickler-Simulation <simulation@lokal>",
            warnings,
            rawText: text,
            cancellationToken);
        if (reply is null)
        {
            return Problem("Der simulierte Treffer konnte nicht gespeichert werden.");
        }

        state.MarkReplyReceived(await store.CountAsync(cancellationToken));
        // Gleiches Push-Signal wie der echte Monitor; die Inbox lädt per REST nach.
        await hub.Clients.All.SendAsync(MailboxHub.ReplyReceivedEvent, cancellationToken);

        return Ok(ReceivedReplyDto.Create(reply));
    }

    /// <summary>Kennzeichen-Teil der Referenz („Nr/Jahr Abteilung_Kennzeichen").</summary>
    static string? KennzeichenAusReferenz(string referenz)
    {
        var trennerIndex = referenz.IndexOf('_');
        return trennerIndex >= 0 && trennerIndex < referenz.Length - 1
            ? referenz[(trennerIndex + 1)..].Trim()
            : null;
    }

    static string Fallback(string? wert, string? ersatz) =>
        !string.IsNullOrWhiteSpace(wert) ? wert.Trim() : (ersatz ?? string.Empty);
}
