using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Backup.Presentation.Controllers;

/// <summary>
/// Sicherung/Wiederherstellung des gesamten Bestands als <em>eine</em> Datei: ein
/// Download (Export) bzw. ein Upload (Import). Die Datei ist ein ZIP mit der
/// Datenbank und den Word-Vorlagen. Gedacht für manuelle Backups und den
/// Datenumzug über App-Updates hinweg. Das Multipart-Feld beim Import heißt
/// <c>datei</c>; ältere Sicherungen (blanke .db) werden weiterhin angenommen.
///
/// Dazu die Arbeitsplatz-Übergabe (§7.2, #39) unter <c>uebergabe</c>: Sie
/// beantwortet beim Start die Frage, ob am anderen Rechner ein neuerer Stand
/// liegt, und spielt ihn auf ausdrücklichen Auftrag ein — über denselben Import
/// wie oben, nur mit einer Datei aus dem eingestellten Ablageordner statt aus
/// einem Dateidialog.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class BackupController(
    IDatabaseBackupService backupService,
    IArbeitsplatzUebergabe uebergabe) : ControllerBase
{
    [HttpGet("export")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Export(CancellationToken cancellationToken)
    {
        var pfad = await backupService.CreateBackupFileAsync(cancellationToken);
        var dateiname = $"automation-backup-{DateTime.Now:yyyyMMdd-HHmmss}.zip";
        // DeleteOnClose: die temporäre Sicherungsdatei verschwindet automatisch,
        // sobald der Download fertig gestreamt (und der Stream geschlossen) ist.
        var stream = new FileStream(
            pfad, FileMode.Open, FileAccess.Read, FileShare.Read,
            bufferSize: 81920, FileOptions.DeleteOnClose | FileOptions.Asynchronous);
        return File(stream, "application/zip", dateiname);
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
            return Problem(
                detail: "Keine Sicherungsdatei übermittelt.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        await using var stream = datei.OpenReadStream();
        var ergebnis = await backupService.ImportBackupAsync(stream, cancellationToken);
        var message = "Sicherung eingespielt. Bitte die App neu starten, damit alle "
            + "Ansichten die wiederhergestellten Daten laden."
            + Vorlagenhinweis(ergebnis.UebersprungeneVorlagen);
        return Ok(new { message });
    }

    /// <summary>
    /// Liegt am anderen Arbeitsplatz ein neuerer Stand — und wie ist die letzte
    /// automatische Sicherung ausgegangen? Wird beim Start abgefragt, bevor die
    /// Oberfläche aufgeht.
    /// </summary>
    [HttpGet("uebergabe")]
    [ProducesResponseType(typeof(UebergabeStandDto), StatusCodes.Status200OK)]
    public ActionResult<UebergabeStandDto> Uebergabe() =>
        Ok(UebergabeStandDto.From(uebergabe.Stand()));

    /// <summary>
    /// Übernimmt den angebotenen Stand. Ersetzt den bisherigen Bestand — deshalb
    /// ausschließlich auf Klick und nie von selbst. Der bisherige Stand wird vom
    /// Import vorher vollständig daneben gelegt.
    /// </summary>
    [HttpPost("uebergabe/uebernehmen")]
    [ProducesResponseType(typeof(UebernahmeErgebnisDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<UebernahmeErgebnisDto>> Uebernehmen(
        CancellationToken cancellationToken)
    {
        var ergebnis = await uebergabe.UebernehmenAsync(cancellationToken);
        if (ergebnis.Rechnername is null)
        {
            return Ok(new UebernahmeErgebnisDto(
                false, null, "Es liegt kein neuerer Stand zur Übernahme bereit."));
        }

        return Ok(new UebernahmeErgebnisDto(
            true,
            ergebnis.Rechnername,
            $"Stand von {ergebnis.Rechnername} übernommen."
            + Vorlagenhinweis(ergebnis.UebersprungeneVorlagen)));
    }

    /// <summary>
    /// Bestätigt, dass die Meldung über eine misslungene automatische Sicherung
    /// gelesen wurde. Der Zeitpunkt bleibt stehen, nur die Meldung kommt beim
    /// nächsten Start nicht wieder.
    /// </summary>
    [HttpPost("sicherungsstand/quittieren")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public IActionResult QuittiereSicherungsfehler()
    {
        uebergabe.QuittiereFehler();
        return NoContent();
    }

    /// <summary>
    /// Der Nachsatz über Vorlagen, die nicht ersetzt wurden, weil lokal eine
    /// abweichende Fassung liegt (#33). Beide Einspielwege sagen denselben Satz.
    /// </summary>
    static string Vorlagenhinweis(IReadOnlyList<string> uebersprungen) =>
        uebersprungen.Count == 0
            ? string.Empty
            : " Nicht ersetzt, weil lokal eine abweichende Fassung liegt: "
              + string.Join(", ", uebersprungen) + ".";
}
