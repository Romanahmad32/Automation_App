using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Identity.Client;

namespace AutomationService.Features.MailboxMonitor.Presentation.Controllers;

/// <summary>
/// Liest den Status der Postfach-Überwachung und die vom Monitor erfassten
/// Zentralruf-Antworten (REQUIREMENTS.md §4.3). Die Oberfläche holt die Treffer
/// hierüber ab und quittiert sie.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MailboxController(
    IReceivedReplyStore store,
    MailboxConnectionState state,
    MailboxConfigStore configStore,
    MicrosoftMailOAuthService microsoftOAuth) : ControllerBase
{
    /// <summary>Liefert den hinterlegten Postfach-Zugang (ohne das App-Passwort).</summary>
    [HttpGet("config")]
    [ProducesResponseType(typeof(MailboxConfigDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MailboxConfigDto>> GetConfig(CancellationToken cancellationToken)
    {
        return Ok(await BuildConfigDtoAsync(configStore.Current, cancellationToken));
    }

    /// <summary>
    /// Speichert den Postfach-Zugang und lässt den Monitor sofort mit den neuen
    /// Werten neu verbinden. Ein leeres App-Passwort lässt das gespeicherte unberührt.
    /// </summary>
    [HttpPut("config")]
    [ProducesResponseType(typeof(MailboxConfigDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MailboxConfigDto>> UpdateConfig(
        [FromBody] MailboxConfigUpdateDto update,
        CancellationToken cancellationToken)
    {
        var saved = configStore.Update(update.ToDomain());
        return Ok(await BuildConfigDtoAsync(saved, cancellationToken));
    }

    /// <summary>
    /// Startet die Microsoft-Anmeldung für Outlook-Postfächer: öffnet den
    /// Standardbrowser auf der Anmeldeseite und wartet, bis der Nutzer sich
    /// angemeldet hat. Bei Erfolg werden Konto-Adresse und Outlook-Server
    /// automatisch als Postfach-Zugang übernommen — der Monitor verbindet sofort neu.
    /// </summary>
    [HttpPost("microsoft/signin")]
    [ProducesResponseType(typeof(MailboxConfigDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<MailboxConfigDto>> MicrosoftSignIn(CancellationToken cancellationToken)
    {
        string account;
        try
        {
            account = await microsoftOAuth.SignInAsync(cancellationToken);
        }
        catch (Exception exception) when (exception is MsalException or InvalidOperationException)
        {
            return Problem(
                title: "Microsoft-Anmeldung fehlgeschlagen",
                detail: exception.Message,
                statusCode: StatusCodes.Status400BadRequest);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Problem(
                title: "Microsoft-Anmeldung abgebrochen",
                detail: "Die Anmeldung im Browser wurde nicht abgeschlossen (Zeitfenster: 5 Minuten).",
                statusCode: StatusCodes.Status400BadRequest);
        }

        // Konto und Outlook-Server direkt übernehmen — so ist die Einrichtung
        // ein einziger Klick; Update() lässt den Monitor sofort neu verbinden.
        var current = configStore.Current;
        var saved = configStore.Update(new MailboxConfigUpdate(
            current.Enabled,
            MailboxAuthMethod.MicrosoftOAuth,
            Host: "outlook.office365.com",
            Port: 993,
            UseSsl: true,
            Username: account,
            AppPassword: null,
            current.Folder,
            current.SubjectFilter));

        return Ok(await BuildConfigDtoAsync(saved, cancellationToken));
    }

    /// <summary>Meldet das Microsoft-Konto ab und entfernt die gespeicherten Tokens.</summary>
    [HttpPost("microsoft/signout")]
    [ProducesResponseType(typeof(MailboxConfigDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MailboxConfigDto>> MicrosoftSignOut(CancellationToken cancellationToken)
    {
        if (microsoftOAuth.IsAvailable)
        {
            await microsoftOAuth.SignOutAsync(cancellationToken);
            // Ohne Token kann die laufende Verbindung nicht bestehen bleiben —
            // Monitor neu auswerten lassen.
            configStore.NotifyChanged();
        }

        return Ok(await BuildConfigDtoAsync(configStore.Current, cancellationToken));
    }

    private async Task<MailboxConfigDto> BuildConfigDtoAsync(
        MailboxOptions options,
        CancellationToken cancellationToken)
    {
        var account = await microsoftOAuth.GetSignedInAccountAsync(cancellationToken);
        return MailboxConfigDto.From(options, microsoftOAuth.IsAvailable, account);
    }

    [HttpGet("status")]
    [ProducesResponseType(typeof(MailboxStatusDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MailboxStatusDto>> GetStatus(CancellationToken cancellationToken)
    {
        var snapshot = state.Snapshot();
        // Gesamt- und offene Zahl kommen aus der DB (überdauern den Neustart),
        // nicht aus dem flüchtigen In-Memory-Zähler des Verbindungszustands.
        var total = await store.CountAsync(cancellationToken);
        var pending = (await store.GetAllAsync(includeAcknowledged: false, cancellationToken)).Count;
        return Ok(new MailboxStatusDto(
            snapshot.Enabled,
            snapshot.Configured,
            snapshot.Connected,
            snapshot.IdleSupported,
            snapshot.LastConnectedAt,
            snapshot.LastReplyAt,
            snapshot.LastError,
            total,
            pending));
    }

    [HttpGet("replies")]
    [ProducesResponseType(typeof(IReadOnlyList<ReceivedReplyDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ReceivedReplyDto>>> GetReplies(
        [FromQuery] bool includeAcknowledged = false,
        CancellationToken cancellationToken = default)
    {
        var replies = (await store.GetAllAsync(includeAcknowledged, cancellationToken))
            .Select(ReceivedReplyDto.Create)
            .ToList();
        return Ok(replies);
    }

    [HttpPost("replies/{id}/acknowledge")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Acknowledge(string id, CancellationToken cancellationToken)
    {
        return await store.AcknowledgeAsync(id, cancellationToken) ? NoContent() : NotFound();
    }
}
