using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Dtos;
using MailKit;
using MailKit.Security;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.MailboxMonitor.Presentation.Controllers;

[ApiController]
[Route("api/mailbox/nachrichten")]
public sealed class PosteingangController(PosteingangDienst dienst) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(PosteingangSeiteDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public Task<ActionResult<PosteingangSeiteDto>> Seite([FromQuery] string? cursor, CancellationToken ct) =>
        AusfuehrenAsync(async () => PosteingangSeiteDto.From(await dienst.LadeSeiteAsync(cursor, ct)), ct);

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(PosteingangInhaltDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status502BadGateway)]
    public Task<ActionResult<PosteingangInhaltDto>> Inhalt(string id, CancellationToken ct) =>
        AusfuehrenAsync(async () => PosteingangInhaltDto.From(await dienst.LadeInhaltAsync(id, ct)), ct);

    private async Task<ActionResult<T>> AusfuehrenAsync<T>(Func<Task<T>> aktion, CancellationToken ct)
    {
        try
        {
            return Ok(await aktion());
        }
        catch (PosteingangException ex)
        {
            return Problem(title: "Posteingang konnte nicht geladen werden", detail: ex.Message, statusCode: ex.Status);
        }
        catch (AuthenticationException)
        {
            return Problem(title: "Postfach-Anmeldung fehlgeschlagen", detail: "Bitte die Zugangsdaten unter Einstellungen → E-Mail prüfen.", statusCode: 502);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            return Problem(title: "Abruf abgebrochen", detail: "Zeitüberschreitung oder geänderter Zugang. Bitte erneut laden.", statusCode: 502);
        }
        catch (Exception ex) when (ex is IOException or CommandException or ProtocolException or System.Net.Sockets.SocketException)
        {
            return Problem(title: "Postfach nicht erreichbar", detail: "Bitte die Internetverbindung und die Serverdaten prüfen und erneut laden.", statusCode: 502);
        }
    }
}
