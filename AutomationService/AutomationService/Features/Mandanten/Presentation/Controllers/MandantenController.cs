using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using AutomationService.Features.Mandanten.Presentation.Dtos;
using Microsoft.AspNetCore.Mvc;

namespace AutomationService.Features.Mandanten.Presentation.Controllers;

/// <summary>
/// CRUD über das Mandantenregister (§5.1). Ersetzt den früheren lokalen
/// JSON-Speicher des Frontends (mandanten.json). Namens-Dubletten und schon
/// vergebene Akten-Ordner ergeben 409, unbekannte IDs 404.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MandantenController(IMandantenRepository repository) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<MandantDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MandantDto>>> GetAll(CancellationToken cancellationToken)
    {
        var mandanten = await repository.GetAllAsync(cancellationToken);
        return Ok(mandanten.Select(MandantDto.From).ToList());
    }

    /// <summary>
    /// Ein Ausschnitt des Registers für die Mandantenliste. In der Kanzlei
    /// stehen dort tausende Mandanten; sie alle auf einmal zu holen ist der
    /// Abruf, den die Liste nicht braucht.
    ///
    /// <c>suche</c> läuft über den <b>ganzen</b> Bestand, nicht über den
    /// gerade geholten Ausschnitt — sonst hinge es am Scrollstand, ob ein
    /// Mandant gefunden wird.
    /// </summary>
    [HttpGet("seite")]
    [ProducesResponseType(typeof(MandantenSeiteDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<MandantenSeiteDto>> GetSeite(
        CancellationToken cancellationToken,
        [FromQuery] string? suche = null,
        [FromQuery] int ueberspringen = 0,
        [FromQuery] int anzahl = 0)
    {
        var seite = await repository.GetSeiteAsync(suche, ueberspringen, anzahl, cancellationToken);
        return Ok(MandantenSeiteDto.From(seite));
    }

    /// <summary>
    /// Die Namen aller zugeordneten Akten-Ordner. Der Zuordnungsstapel teilt
    /// damit die gescannten Ordner in „zugeordnet" und „offen" — eine Seite
    /// des Registers reicht dafür nicht, und die Mandanten dafür vollständig
    /// zu holen wäre genau der Abruf, den <c>seite</c> vermeidet.
    /// </summary>
    [HttpGet("aktenordner")]
    [ProducesResponseType(typeof(IReadOnlyList<string>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<string>>> GetAktenOrdnernamen(
        CancellationToken cancellationToken)
    {
        return Ok(await repository.GetAktenOrdnernamenAsync(cancellationToken));
    }

    [HttpPost]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MandantDto>> Create(
        [FromBody] CreateMandantDto dto,
        CancellationToken cancellationToken)
    {
        var created = await repository.CreateAsync(ToEntity(dto), cancellationToken);
        return CreatedAtAction(nameof(GetAll), MandantDto.From(created));
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MandantDto>> Update(
        int id,
        [FromBody] MandantDto dto,
        CancellationToken cancellationToken)
    {
        var updated = await repository.UpdateAsync(ToEntity(dto with { Id = id }), cancellationToken);
        return updated is null
            ? Problem(detail: $"Mandant mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound)
            : Ok(MandantDto.From(updated));
    }

    /// <summary>
    /// Gibt dem Mandanten einen Akten-Ordner — aus dem Zuordnungsstapel, von der
    /// Mandantenkarte und nach einer Ablage. Nur dieser eine Ordner ändert sich:
    /// Wer den ganzen Mandanten per <c>PUT</c> schickte, überschriebe eine
    /// gleichzeitige zweite Änderung an ihm.
    ///
    /// <c>nurPruefen=true</c> schreibt nichts und antwortet wie die Zuordnung —
    /// 409, wenn der Ordner einem anderen gehört. Die Ablage fragt so vor dem
    /// Kopieren, statt dafür das ganze Register zu laden.
    /// </summary>
    [HttpPost("{id:int}/aktenordner/zuordnen")]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MandantDto>> OrdnerZuordnen(
        int id,
        [FromBody] AktenOrdnerDto dto,
        CancellationToken cancellationToken,
        [FromQuery] bool nurPruefen = false)
    {
        if (string.IsNullOrWhiteSpace(dto.Ordnername))
        {
            return Problem(detail: "Ohne Ordnernamen lässt sich nichts zuordnen.", statusCode: StatusCodes.Status400BadRequest);
        }

        var mandant = await repository.OrdnerZuordnenAsync(id, dto.Ordnername, nurPruefen, cancellationToken);
        return mandant is null
            ? Problem(detail: $"Mandant mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound)
            : Ok(MandantDto.From(mandant));
    }

    /// <summary>
    /// Nimmt dem Mandanten einen Akten-Ordner, gleich in welcher Schreibweise er
    /// dort steht. Der Ordner im Dateisystem bleibt unberührt.
    /// </summary>
    [HttpPost("{id:int}/aktenordner/loesen")]
    [ProducesResponseType(typeof(MandantDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<MandantDto>> OrdnerLoesen(
        int id,
        [FromBody] AktenOrdnerDto dto,
        CancellationToken cancellationToken)
    {
        var mandant = await repository.OrdnerLoesenAsync(id, dto.Ordnername, cancellationToken);
        return mandant is null
            ? Problem(detail: $"Mandant mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound)
            : Ok(MandantDto.From(mandant));
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var removed = await repository.DeleteAsync(id, cancellationToken);
        return removed
            ? NoContent()
            : Problem(detail: $"Mandant mit ID {id} nicht gefunden", statusCode: StatusCodes.Status404NotFound);
    }

    static MandantEntity ToEntity(CreateMandantDto dto) => new()
    {
        Anrede = dto.Anrede,
        Vorname = dto.Vorname,
        Nachname = dto.Nachname,
        StrasseHausnummer = dto.StrasseHausnummer,
        Postleitzahl = dto.Postleitzahl,
        Ort = dto.Ort,
        EmailAdresse = dto.EmailAdresse,
        Telefonnummer = dto.Telefonnummer,
        Notiz = dto.Notiz,
        PersoenlicheGrussformel = dto.PersoenlicheGrussformel,
        AktenOrdnernamenJson = MandantListen.Schreib(dto.AktenOrdnernamen),
        KennzeichenJson = MandantListen.Schreib(dto.Kennzeichen),
    };

    static MandantEntity ToEntity(MandantDto dto) => new()
    {
        Id = dto.Id,
        Anrede = dto.Anrede,
        Vorname = dto.Vorname,
        Nachname = dto.Nachname,
        StrasseHausnummer = dto.StrasseHausnummer,
        Postleitzahl = dto.Postleitzahl,
        Ort = dto.Ort,
        EmailAdresse = dto.EmailAdresse,
        Telefonnummer = dto.Telefonnummer,
        Notiz = dto.Notiz,
        PersoenlicheGrussformel = dto.PersoenlicheGrussformel,
        AktenOrdnernamenJson = MandantListen.Schreib(dto.AktenOrdnernamen),
        KennzeichenJson = MandantListen.Schreib(dto.Kennzeichen),
    };
}
