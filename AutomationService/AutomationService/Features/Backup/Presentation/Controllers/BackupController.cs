using AutomationService.Features.Backup.Domain.Services;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Backup.Presentation.Controllers;

/// <summary>
/// Sicherung/Wiederherstellung der gesamten Datenbank als <em>eine</em> Datei:
/// ein Download (Export) bzw. ein Upload (Import). Gedacht für manuelle Backups
/// und den Datenumzug über App-Updates hinweg. Das Multipart-Feld beim Import
/// heißt <c>datei</c>.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class BackupController(IDatabaseBackupService backupService) : ControllerBase
{
    [HttpGet("export")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Export(CancellationToken cancellationToken)
    {
        var pfad = await backupService.CreateBackupFileAsync(cancellationToken);
        var dateiname = $"automation-backup-{DateTime.Now:yyyyMMdd-HHmmss}.db";
        // DeleteOnClose: die temporäre Sicherungsdatei verschwindet automatisch,
        // sobald der Download fertig gestreamt (und der Stream geschlossen) ist.
        var stream = new FileStream(
            pfad, FileMode.Open, FileAccess.Read, FileShare.Read,
            bufferSize: 81920, FileOptions.DeleteOnClose | FileOptions.Asynchronous);
        return File(stream, "application/octet-stream", dateiname);
    }

    [HttpPost("import")]
    [RequestSizeLimit(1L * 1024 * 1024 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = 1L * 1024 * 1024 * 1024)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Import(IFormFile datei, CancellationToken cancellationToken)
    {
        if (datei is null || datei.Length == 0)
        {
            return BadRequest("Keine Sicherungsdatei übermittelt.");
        }

        try
        {
            await using var stream = datei.OpenReadStream();
            await backupService.ImportBackupAsync(stream, cancellationToken);
            return Ok(new
            {
                message = "Sicherung eingespielt. Bitte die App neu starten, damit alle "
                    + "Ansichten die wiederhergestellten Daten laden.",
            });
        }
        catch (InvalidBackupException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}
